
function crawl(rootItem, sectionId) {
    let results = [];

    function traverse(item, currentSubSection) {
        if (!item) return;

        // Determine subsection context
        // We look for 'settingsSection' property which we will add to section containers
        let subSection = currentSubSection;
        if (item.hasOwnProperty("settingsSection")) {
            subSection = item.settingsSection;
        }

        // Check if this is a searchable setting
        // We look for items with a 'label' property.
        // We verify it's likely a setting and not just a header or label by checking for:
        // - It's inside a defined subSection (avoiding top-level layout items)
        // - OR it explicitly has 'keywords' (if user added them)
        // - OR it has 'checked' (Toggle) or 'value' (Input) properties
        
        let isSetting = false;
        if (item.hasOwnProperty("label") && typeof item.label === "string" && item.label.length > 0) {
            // It has a label. Is it a setting?
            // Exclude pure Labels/Text items (which usually don't have 'label' prop, they have 'text' prop)
            // But our custom components (ToggleRow, etc) use 'label'.
            // So 'label' existence is a very strong indicator.
            isSetting = true;
        }

        if (isSetting) {
            let label = item.label;
            
            // Build keywords
            let keywords = [];
            if (item.hasOwnProperty("keywords")) keywords.push(item.keywords);
            if (item.hasOwnProperty("description")) keywords.push(item.description);
            // Add label parts to keywords
            keywords.push(label);
            
            // Deduce icon if possible (optional)
            let icon = "";
            if (item.hasOwnProperty("icon")) icon = item.icon;

            results.push({
                label: label,
                keywords: keywords.join(" "),
                section: sectionId,
                subSection: subSection || "", // Default to empty if top-level
                subLabel: "", // Can be enhanced later
                icon: icon, // Can be enhanced later
                isIcon: true // Default
            });
        }

        // Traverse children
        // Visual children
        if (item.children) {
            for (let i = 0; i < item.children.length; i++) {
                traverse(item.children[i], subSection);
            }
        }
        
        // ContentItem (for Control-derived types)
        if (item.contentItem) {
            traverse(item.contentItem, subSection);
        }
    }

    traverse(rootItem, "");
    return results;
}
