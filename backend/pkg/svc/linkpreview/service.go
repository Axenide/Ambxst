package linkpreview

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"

	"ambxst/backend/pkg/ipc"
	"golang.org/x/net/html"
)

// Service fetches Open Graph / Twitter Card metadata for URLs (link previews
// in the clipboard), replacing scripts/link_preview.py.
type Service struct {
	client *http.Client
}

func NewService() *Service {
	return &Service{
		client: &http.Client{Timeout: 15 * time.Second},
	}
}

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "linkpreview",
		Methods: map[string]ipc.HandlerFunc{
			"fetch": s.fetch,
		},
	})
}

type meta struct {
	Title       string `json:"title"`
	Description string `json:"description"`
	Image       string `json:"image"`
	URL         string `json:"url"`
	RequestURL  string `json:"request_url"`
	SiteName    string `json:"site_name"`
	Type        string `json:"type"`
	Favicon     string `json:"favicon"`
	Author      string `json:"author,omitempty"`
	VideoID     string `json:"video_id,omitempty"`
}

func (s *Service) fetch(params json.RawMessage) (any, error) {
	var p struct {
		URL     string `json:"url"`
		Timeout int    `json:"timeout"`
	}
	json.Unmarshal(params, &p)
	p.URL = strings.TrimSpace(p.URL)
	if p.URL == "" {
		return map[string]any{"error": "No URL provided"}, nil
	}
	timeout := time.Duration(p.Timeout) * time.Second
	if timeout <= 0 {
		timeout = 5 * time.Second
	}
	res := s.fetchPreview(p.URL, timeout)
	return res, nil
}

var youTubeIDRe = regexp.MustCompile(`(?:youtube\.com/(?:watch\?v=|embed/|v/|shorts/)|youtu\.be/)([a-zA-Z0-9_-]{11})`)

func (s *Service) fetchPreview(rawurl string, timeout time.Duration) map[string]any {
	if !strings.HasPrefix(rawurl, "http://") && !strings.HasPrefix(rawurl, "https://") {
		return map[string]any{"error": "Invalid URL"}
	}

	if strings.Contains(rawurl, "youtube.com") || strings.Contains(rawurl, "youtu.be") {
		if m := s.fetchYouTube(rawurl, timeout); m != nil {
			return m
		}
	}
	if strings.Contains(rawurl, "twitter.com") || strings.Contains(rawurl, "x.com") {
		if m := s.fetchTwitter(rawurl, timeout); m != nil {
			return m
		}
	}
	return s.fetchGeneric(rawurl, timeout)
}

func (s *Service) fetchYouTube(rawurl string, timeout time.Duration) map[string]any {
	id := youTubeIDRe.FindStringSubmatch(rawurl)
	if len(id) < 2 {
		return nil
	}
	oembed := fmt.Sprintf("https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=%s&format=json", id[1])
	var data struct {
		Title        string `json:"title"`
		AuthorName   string `json:"author_name"`
		ThumbnailURL string `json:"thumbnail_url"`
	}
	if err := s.getJSON(oembed, &data, timeout); err != nil {
		return nil
	}
	thumb := data.ThumbnailURL
	thumb = strings.Replace(thumb, "hqdefault", "maxresdefault", 1)
	return map[string]any{
		"title":       data.Title,
		"description": data.AuthorName,
		"image":       thumb,
		"url":         rawurl,
		"request_url": rawurl,
		"site_name":   "YouTube",
		"type":        "video",
		"favicon":     "https://www.youtube.com/s/desktop/9c0f82da/img/favicon_144x144.png",
		"author":      data.AuthorName,
		"video_id":    id[1],
	}
}

func (s *Service) fetchTwitter(rawurl string, timeout time.Duration) map[string]any {
	oembed := "https://publish.twitter.com/oembed?url=" + url.QueryEscape(rawurl)
	var data struct {
		AuthorName string `json:"author_name"`
		HTML       string `json:"html"`
	}
	if err := s.getJSON(oembed, &data, timeout); err != nil {
		return nil
	}
	re := regexp.MustCompile(`<[^>]+>`)
	desc := re.ReplaceAllString(data.HTML, "")
	return map[string]any{
		"title":       data.AuthorName,
		"description": desc,
		"image":       "",
		"url":         rawurl,
		"request_url": rawurl,
		"site_name":   "X (Twitter)",
		"type":        "article",
		"favicon":     "https://abs.twimg.com/favicons/twitter.3.ico",
		"author":      data.AuthorName,
	}
}

func (s *Service) fetchGeneric(rawurl string, timeout time.Duration) map[string]any {
	req, err := http.NewRequest("GET", rawurl, nil)
	if err != nil {
		return map[string]any{"error": "Invalid URL"}
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
	req.Header.Set("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
	req.Header.Set("Accept-Language", "en-US,en;q=0.5")
	req.Header.Set("Accept-Encoding", "identity")
	req.Header.Set("Connection", "close")

	httpClient := *s.client
	httpClient.Timeout = timeout
	resp, err := httpClient.Do(req)
	if err != nil {
		return map[string]any{"error": fmt.Sprintf("Connection failed: %v", err), "url": rawurl, "request_url": rawurl}
	}
	defer resp.Body.Close()
	finalURL := resp.Request.URL.String()
	ct := resp.Header.Get("Content-Type")
	if !strings.Contains(ct, "text/html") {
		return map[string]any{"error": "Not an HTML page", "url": rawurl, "request_url": rawurl}
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 500*1024))
	if err != nil {
		return map[string]any{"error": fmt.Sprintf("Failed to read: %v", err), "url": rawurl, "request_url": rawurl}
	}

	m := s.parseHTML(string(body), finalURL, rawurl)
	return m
}

func (s *Service) parseHTML(page, finalURL, requestURL string) map[string]any {
	meta := &meta{
		Type:       "website",
		RequestURL: requestURL,
		URL:        requestURL,
	}
	parsedFinal, _ := url.Parse(finalURL)

	var faviconCandidates []struct {
		href     string
		size     int
		priority int
	}
	titleFallback := ""

	doc, err := html.Parse(strings.NewReader(page))
	if err == nil {
		var walk func(*html.Node)
		walk = func(n *html.Node) {
			if n.Type == html.ElementNode {
				switch strings.ToLower(n.Data) {
				case "title":
					if n.FirstChild != nil {
						titleFallback = n.FirstChild.Data
					}
				case "link":
					var rel, href, sizes, linkType string
					for _, a := range n.Attr {
						switch a.Key {
						case "rel":
							rel = a.Val
						case "href":
							href = a.Val
						case "sizes":
							sizes = a.Val
						case "type":
							linkType = a.Val
						}
					}
					if rel != "" && href != "" && strings.Contains(strings.ToLower(rel), "icon") {
						priority := 1
						hl := strings.ToLower(href)
						if strings.Contains(hl, ".svg") || strings.Contains(strings.ToLower(linkType), "svg") {
							priority = 3
						} else if strings.Contains(hl, ".png") || strings.Contains(strings.ToLower(linkType), "png") {
							priority = 2
						}
						size := 0
						if strings.Contains(sizes, "x") {
							fmt.Sscanf(sizes, "%dx", &size)
						}
						faviconCandidates = append(faviconCandidates, struct {
							href     string
							size     int
							priority int
						}{href, size, priority})
						if meta.Favicon == "" {
							meta.Favicon = href
						}
					}
				case "meta":
					var prop, name, content string
					for _, a := range n.Attr {
						switch a.Key {
						case "property":
							prop = a.Val
						case "name":
							name = a.Val
						case "content":
							content = a.Val
						}
					}
					if content == "" {
						break
					}
					switch prop {
					case "og:title":
						meta.Title = content
					case "og:description":
						meta.Description = content
					case "og:image":
						meta.Image = content
					case "og:url":
						meta.URL = content
					case "og:site_name":
						meta.SiteName = content
					case "og:type":
						meta.Type = content
					}
					if meta.Title == "" && name == "twitter:title" {
						meta.Title = content
					} else if meta.Description == "" && (name == "twitter:description" || name == "description") {
						meta.Description = content
					} else if meta.Image == "" && name == "twitter:image" {
						meta.Image = content
					}
				}
			}
			for c := n.FirstChild; c != nil; c = c.NextSibling {
				walk(c)
			}
		}
		walk(doc)
	}

	if meta.Title == "" {
		meta.Title = strings.TrimSpace(titleFallback)
	}

	if parsedFinal != nil {
		base := parsedFinal.Scheme + "://" + parsedFinal.Hostname()
		meta.Image = resolveURL(meta.Image, finalURL, base)
		meta.Favicon = resolveURL(meta.Favicon, finalURL, base)
		if meta.Favicon == "" {
			meta.Favicon = base + "/favicon.ico"
		}
		if meta.SiteName == "" {
			meta.SiteName = parsedFinal.Hostname()
		}
	}

	// Best favicon: priority (svg>png>ico) then size score.
	if len(faviconCandidates) > 0 {
		best := faviconCandidates[0]
		bestScore := faviconScore(best.size)
		for _, c := range faviconCandidates[1:] {
			sc := faviconScore(c.size)
			if c.priority > best.priority || (c.priority == best.priority && sc > bestScore) {
				best, bestScore = c, sc
			}
		}
		if parsedFinal != nil {
			base := parsedFinal.Scheme + "://" + parsedFinal.Hostname()
			meta.Favicon = resolveURL(best.href, finalURL, base)
		}
	}

	return map[string]any{
		"title":       meta.Title,
		"description": meta.Description,
		"image":       meta.Image,
		"url":         meta.URL,
		"request_url": requestURL,
		"site_name":   meta.SiteName,
		"type":        meta.Type,
		"favicon":     meta.Favicon,
	}
}

func faviconScore(size int) int {
	if 32 <= size && size <= 128 {
		return size
	}
	if size > 128 {
		return 128 - (size-128)/10
	}
	return size
}

func resolveURL(ref, finalURL, base string) string {
	ref = strings.TrimSpace(ref)
	if ref == "" {
		return ""
	}
	if strings.HasPrefix(ref, "http://") || strings.HasPrefix(ref, "https://") {
		return ref
	}
	if ref == "" {
		return ""
	}
	baseURL, err := url.Parse(finalURL)
	if err != nil {
		return ""
	}
	rel, err := url.Parse(ref)
	if err != nil {
		return ""
	}
	return baseURL.ResolveReference(rel).String()
}

func (s *Service) getJSON(rawurl string, dest any, timeout time.Duration) error {
	req, _ := http.NewRequest("GET", rawurl, nil)
	req.Header.Set("User-Agent", "Mozilla/5.0")
	httpClient := *s.client
	httpClient.Timeout = timeout
	resp, err := httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}
	return json.Unmarshal(data, dest)
}
