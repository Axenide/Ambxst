package compositor

// Input is the JSON-RPC payload the QML shell assembles and passes to the
// compositor service on every regeneration trigger. The shape is
// deliberately flat (no nested JsonAdapter access) so the Go side can be
// tested without depending on Quickshell.
type Input struct {
	Compositor CompositorConfig `json:"compositor"`
	Theme      ThemeConfig      `json:"theme"`
	Bar        BarConfig        `json:"bar"`
	Layout     string           `json:"layout"`
	Keybinds   KeybindsConfig   `json:"keybinds"`
}

type CompositorConfig struct {
	GapsIn              int          `json:"gapsIn"`
	GapsOut             int          `json:"gapsOut"`
	BorderSize          int          `json:"borderSize"`
	Rounding            int          `json:"rounding"`
	SyncBorderColor     bool         `json:"syncBorderColor"`
	BorderColor         string       `json:"borderColor"`
	ActiveBorderColor   []string     `json:"activeBorderColor"`
	ActiveBorderAngle   int          `json:"activeBorderAngle"`
	InactiveBorderColor []string     `json:"inactiveBorderColor"`
	InactiveBorderAngle int          `json:"inactiveBorderAngle"`
	Shadow              ShadowConfig `json:"shadow"`
	Blur                BlurConfig   `json:"blur"`
	Animations          Animations   `json:"animations"`
}

type ShadowConfig struct {
	Enabled       bool    `json:"enabled"`
	Range         int     `json:"range"`
	RenderPower   int     `json:"renderPower"`
	Sharp         bool    `json:"sharp"`
	IgnoreWindow  bool    `json:"ignoreWindow"`
	Color         string  `json:"color"`
	ColorInactive string  `json:"colorInactive"`
	Opacity       float64 `json:"opacity"`
	Offset        string  `json:"offset"`
	Scale         float64 `json:"scale"`
}

type BlurConfig struct {
	Enabled                 bool    `json:"enabled"`
	Size                    int     `json:"size"`
	Passes                  int     `json:"passes"`
	IgnoreOpacity           bool    `json:"ignoreOpacity"`
	ExplicitIgnoreAlpha     bool    `json:"explicitIgnoreAlpha"`
	IgnoreAlphaValue        float64 `json:"ignoreAlphaValue"`
	NewOptimizations        bool    `json:"newOptimizations"`
	Xray                    bool    `json:"xray"`
	Noise                   float64 `json:"noise"`
	Contrast                float64 `json:"contrast"`
	Brightness              float64 `json:"brightness"`
	Vibrancy                float64 `json:"vibrancy"`
	VibrancyDarkness        float64 `json:"vibrancyDarkness"`
	Special                 bool    `json:"special"`
	Popups                  bool    `json:"popups"`
	PopupsIgnorealpha       float64 `json:"popupsIgnorealpha"`
	InputMethods            bool    `json:"inputMethods"`
	InputMethodsIgnorealpha float64 `json:"inputMethodsIgnorealpha"`
}

type Animations struct {
	Enabled bool `json:"enabled"`
}

type ThemeConfig struct {
	SrBarBgOpacity float64 `json:"srBarBgOpacity"`
	SrBgOpacity    float64 `json:"srBgOpacity"`
	ShadowColor    string  `json:"shadowColor"`
	ShadowOpacity  float64 `json:"shadowOpacity"`
}

type BarConfig struct {
	Position string `json:"position"`
}

// KeybindsConfig mirrors the shape Config.keybindsLoader.adapter exposes in
// QML: a flat map of ambxst core binds, a nested system section, and a
// custom array of (keys x actions) binds.
type KeybindsConfig struct {
	Ambxst map[string]Keybind `json:"ambxst"`
	System map[string]Keybind `json:"system"`
	Custom []CustomBind       `json:"custom"`
}

type Keybind struct {
	Modifiers []string `json:"modifiers"`
	Key       string   `json:"key"`
	Action    Action   `json:"action"`
}

// Action is the wire form of a KeybindActions catalog entry, or the legacy
// {dispatcher, argument, flags} triple. Exactly one of ID or Dispatcher is
// populated on a valid action.
type Action struct {
	ID         string         `json:"id,omitempty"`
	Args       map[string]any `json:"args,omitempty"`
	Dispatcher string         `json:"dispatcher,omitempty"`
	Argument   string         `json:"argument,omitempty"`
	Flags      string         `json:"flags,omitempty"`
	Layouts    []string       `json:"layouts,omitempty"`
}

type CustomBind struct {
	Name    string    `json:"name"`
	Keys    []KeySpec `json:"keys"`
	Actions []Action  `json:"actions"`
	Enabled bool      `json:"enabled"`
}

type KeySpec struct {
	Modifiers []string `json:"modifiers"`
	Key       string   `json:"key"`
}
