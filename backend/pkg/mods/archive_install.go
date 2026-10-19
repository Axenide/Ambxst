package mods

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// ArchivePreview is the package information shown before a local archive is
// installed. The digest binds the confirmation to the exact bytes inspected.
type ArchivePreview struct {
	Source        string   `json:"source"`
	SHA256        string   `json:"sha256"`
	Size          int64    `json:"size"`
	ID            string   `json:"id"`
	Name          string   `json:"name"`
	Version       string   `json:"version"`
	Description   string   `json:"description"`
	License       string   `json:"license,omitempty"`
	Author        string   `json:"author,omitempty"`
	AuthorURL     string   `json:"authorUrl,omitempty"`
	Homepage      string   `json:"homepage,omitempty"`
	Dependencies  []string `json:"dependencies,omitempty"`
	Conflicts     []string `json:"conflicts,omitempty"`
	Commands      []string `json:"commands,omitempty"`
	Permissions   []string `json:"permissions,omitempty"`
	AffectedFiles []string `json:"affectedFiles"`
	UnknownFields []string `json:"unknownFields,omitempty"`
}

func (m *Manager) PreviewArchive(source string) (ArchivePreview, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if err := os.MkdirAll(m.paths.ModPackagesDir(), 0o755); err != nil {
		return ArchivePreview{}, err
	}
	tmp, err := os.MkdirTemp(m.paths.ModPackagesDir(), ".preview-")
	if err != nil {
		return ArchivePreview{}, err
	}
	defer os.RemoveAll(tmp)

	absolute, archivePath, digest, size, err := copyArchiveForReview(source, tmp)
	if err != nil {
		return ArchivePreview{}, err
	}
	extracted := filepath.Join(tmp, "package")
	if err := extractPackageArchive(archivePath, extracted); err != nil {
		return ArchivePreview{}, err
	}
	packageRoot, err := locatePackageRoot(extracted)
	if err != nil {
		return ArchivePreview{}, err
	}
	manifest, err := LoadManifest(packageRoot)
	if err != nil {
		return ArchivePreview{}, err
	}
	state, err := m.loadState()
	if err != nil {
		return ArchivePreview{}, err
	}
	if _, installed := findInstalled(state, manifest.ID); installed {
		return ArchivePreview{}, fmt.Errorf("mod %q is already installed", manifest.ID)
	}
	files, err := manifest.AffectedFiles(packageRoot)
	if err != nil {
		return ArchivePreview{}, err
	}
	return ArchivePreview{
		Source: absolute, SHA256: digest, Size: size,
		ID: manifest.ID, Name: manifest.Name, Version: manifest.Version,
		Description: manifest.Description, License: manifest.License,
		Author: manifest.Author, AuthorURL: manifest.AuthorURL, Homepage: manifest.Homepage,
		Dependencies: manifest.Dependencies, Conflicts: manifest.Conflicts,
		Commands: manifest.Commands, Permissions: manifest.Permissions,
		AffectedFiles: files, UnknownFields: manifest.UnknownFields,
	}, nil
}

func (m *Manager) InstallArchive(source, expectedSHA256 string) (Status, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if err := m.guardUpdateTrial(); err != nil {
		return Status{}, err
	}
	if !sha256Pattern.MatchString(expectedSHA256) {
		return Status{}, fmt.Errorf("a valid reviewed archive SHA-256 is required")
	}
	if err := os.MkdirAll(m.paths.ModPackagesDir(), 0o755); err != nil {
		return Status{}, err
	}
	tmp, err := os.MkdirTemp(m.paths.ModPackagesDir(), ".install-")
	if err != nil {
		return Status{}, err
	}
	defer os.RemoveAll(tmp)

	absolute, archivePath, digest, _, err := copyArchiveForReview(source, tmp)
	if err != nil {
		return Status{}, err
	}
	if !strings.EqualFold(digest, expectedSHA256) {
		return Status{}, fmt.Errorf("archive changed after review; choose it again")
	}
	fetched, err := acquirePackage(archivePath, filepath.Join(tmp, "package"))
	if err != nil {
		return Status{}, err
	}
	// Keep the user's original path as the manual-update source, not our
	// short-lived verified copy.
	fetched.source = absolute
	return m.installFetchedLocked(fetched)
}

func copyArchiveForReview(source, destination string) (absolute, copied, digest string, size int64, err error) {
	absolute, suffix, err := validateArchiveSource(source)
	if err != nil {
		return "", "", "", 0, err
	}
	input, err := os.Open(absolute)
	if err != nil {
		return "", "", "", 0, err
	}
	defer input.Close()

	copied = filepath.Join(destination, "review"+suffix)
	output, err := os.OpenFile(copied, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
	if err != nil {
		return "", "", "", 0, err
	}
	hash := sha256.New()
	size, copyErr := io.Copy(io.MultiWriter(output, hash), io.LimitReader(input, maxPackageBytes+1))
	closeErr := output.Close()
	if err := errors.Join(copyErr, closeErr); err != nil {
		return "", "", "", 0, err
	}
	if size > maxPackageBytes {
		return "", "", "", 0, fmt.Errorf("archive is larger than the %d MiB limit", maxPackageBytes>>20)
	}
	return absolute, copied, hex.EncodeToString(hash.Sum(nil)), size, nil
}

func validateArchiveSource(source string) (string, string, error) {
	source = strings.TrimSpace(source)
	if source == "" {
		return "", "", fmt.Errorf("archive path is required")
	}
	absolute, err := filepath.Abs(source)
	if err != nil {
		return "", "", err
	}
	info, err := os.Stat(absolute)
	if err != nil {
		return "", "", fmt.Errorf("inspect archive: %w", err)
	}
	if !info.Mode().IsRegular() {
		return "", "", fmt.Errorf("archive is not a regular file")
	}
	if info.Size() > maxPackageBytes {
		return "", "", fmt.Errorf("archive is larger than the %d MiB limit", maxPackageBytes>>20)
	}
	lower := strings.ToLower(absolute)
	for _, suffix := range []string{".tar.gz", ".tgz", ".zip", ".tar"} {
		if strings.HasSuffix(lower, suffix) {
			return absolute, suffix, nil
		}
	}
	return "", "", fmt.Errorf("unsupported package archive")
}

func recordArchiveEntry(seen map[string]bool, name string, directory bool) error {
	clean := filepath.ToSlash(filepath.Clean(name))
	if len(clean) > 4096 || strings.Count(clean, "/") > 64 {
		return fmt.Errorf("archive path is too long: %q", name)
	}
	if previousDirectory, exists := seen[clean]; exists {
		if directory && previousDirectory {
			return nil
		}
		return fmt.Errorf("archive contains duplicate path %q", name)
	}
	seen[clean] = directory
	return nil
}
