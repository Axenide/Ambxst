import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.config
import "notes_utils.js" as NotesUtils

Item {
    id: root
    focus: true

    // Prefix support
    property string prefixIcon: ""
    signal backspaceOnEmpty

    property int leftPanelWidth: 0

    // Notes directory configuration
    property string notesDir: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/ambxst-notes"
    property string indexPath: notesDir + "/index.json"
    property string notesPath: notesDir + "/notes"
    property string noteExtension: ".html"  // Store as HTML for rich text (Markdown uses .md)

    // Search and selection state
    property string searchText: ""
    property bool showResults: searchText.length > 0
    property int selectedIndex: -1
    property var allNotes: []
    property var filteredNotes: []

    // List model
    ListModel {
        id: notesModel
    }

    // Delete mode state
    property bool deleteMode: false
    property string noteToDelete: ""
    property int originalSelectedIndex: -1
    property int deleteButtonIndex: 0

    // Rename mode state
    property bool renameMode: false
    property string noteToRename: ""
    property string newNoteName: ""
    property int renameSelectedIndex: -1
    property int renameButtonIndex: 0
    property string pendingRenamedNote: ""

    // Options menu state (expandable list)
    property int expandedItemIndex: -1
    property int selectedOptionIndex: 0
    property bool keyboardNavigation: false

    // Current note content for editor
    property string currentNoteId: ""
    property string currentNoteContent: ""
    property string currentNoteTitle: ""
    property bool currentNoteIsMarkdown: false
    property bool loadingNote: false
    property bool editorDirty: false

    // Create menu state
    property bool showCreateMenu: false
    property int createMenuSelectedIndex: 0

    // Pre-format state (for typing with format when no selection)
    // null = inherit from cursor position, true/false = explicit state
    property var preFormatBold: null
    property var preFormatItalic: null
    property var preFormatUnderline: null
    property var preFormatStrikeout: null
    property var preFormatFontSize: null

    // Check if there's a text selection
    function hasSelection() {
        return noteEditor.selectionStart !== noteEditor.selectionEnd;
    }

    // Toggle bold (handles both selection and pre-format)
    function toggleBold() {
        if (hasSelection()) {
            noteEditor.cursorSelection.font.bold = !noteEditor.cursorSelection.font.bold;
        } else {
            // Toggle based on current visual state
            preFormatBold = !isBold();
        }
        noteEditor.forceActiveFocus();
    }

    // Toggle italic
    function toggleItalic() {
        if (hasSelection()) {
            noteEditor.cursorSelection.font.italic = !noteEditor.cursorSelection.font.italic;
        } else {
            preFormatItalic = !isItalic();
        }
        noteEditor.forceActiveFocus();
    }

    // Toggle underline
    function toggleUnderline() {
        if (hasSelection()) {
            noteEditor.cursorSelection.font.underline = !noteEditor.cursorSelection.font.underline;
        } else {
            preFormatUnderline = !isUnderline();
        }
        noteEditor.forceActiveFocus();
    }

    // Toggle strikeout
    function toggleStrikeout() {
        if (hasSelection()) {
            noteEditor.cursorSelection.font.strikeout = !noteEditor.cursorSelection.font.strikeout;
        } else {
            preFormatStrikeout = !isStrikeout();
        }
        noteEditor.forceActiveFocus();
    }

    // Set font size preserving individual character styles
    function setFontSize(size) {
        if (hasSelection()) {
            let start = noteEditor.selectionStart;
            let end = noteEditor.selectionEnd;

            // Process each character: get its font, change size, reassign
            for (let i = start; i < end; i++) {
                noteEditor.select(i, i + 1);
                let charFont = noteEditor.cursorSelection.font;
                charFont.pixelSize = size;
                noteEditor.cursorSelection.font = charFont;
            }

            // Restore original selection
            noteEditor.select(start, end);
        } else {
            preFormatFontSize = size;
        }
        noteEditor.forceActiveFocus();
    }

    // Get current bold state (selection or pre-format or cursor)
    function isBold() {
        if (hasSelection()) {
            return noteEditor.cursorSelection.font.bold;
        }
        if (preFormatBold !== null) {
            return preFormatBold;
        }
        // Inherit from cursor position
        return noteEditor.cursorSelection.font.bold;
    }

    // Get current italic state
    function isItalic() {
        if (hasSelection()) {
            return noteEditor.cursorSelection.font.italic;
        }
        if (preFormatItalic !== null) {
            return preFormatItalic;
        }
        return noteEditor.cursorSelection.font.italic;
    }

    // Get current underline state
    function isUnderline() {
        if (hasSelection()) {
            return noteEditor.cursorSelection.font.underline;
        }
        if (preFormatUnderline !== null) {
            return preFormatUnderline;
        }
        return noteEditor.cursorSelection.font.underline;
    }

    // Get current strikeout state
    function isStrikeout() {
        if (hasSelection()) {
            return noteEditor.cursorSelection.font.strikeout;
        }
        if (preFormatStrikeout !== null) {
            return preFormatStrikeout;
        }
        return noteEditor.cursorSelection.font.strikeout;
    }

    // Get current font size
    function getCurrentFontSize() {
        if (hasSelection()) {
            return noteEditor.cursorSelection.font.pixelSize || Config.theme.fontSize;
        }
        if (preFormatFontSize !== null) {
            return preFormatFontSize;
        }
        return noteEditor.cursorSelection.font.pixelSize || Config.theme.fontSize;
    }

    // Check if any pre-format is active
    function hasActivePreFormat() {
        return preFormatBold !== null || preFormatItalic !== null || preFormatUnderline !== null || preFormatStrikeout !== null || preFormatFontSize !== null;
    }

    // Reset pre-format state
    function resetPreFormat() {
        preFormatBold = null;
        preFormatItalic = null;
        preFormatUnderline = null;
        preFormatStrikeout = null;
        preFormatFontSize = null;
    }

    // --- Markdown formatting functions ---

    // Property to track current heading level at cursor
    property string mdCurrentHeading: "P"

    // Wrap selected text with markers, or insert markers at cursor
    function mdWrapSelection(prefix, suffix) {
        if (!mdEditor)
            return;

        let start = mdEditor.selectionStart;
        let end = mdEditor.selectionEnd;
        let text = mdEditor.text;

        if (start === end) {
            // No selection - insert markers and place cursor between them
            let newText = text.substring(0, start) + prefix + suffix + text.substring(end);
            mdEditor.text = newText;
            mdEditor.cursorPosition = start + prefix.length;
        } else {
            // Has selection - check if already wrapped
            let selectedText = text.substring(start, end);
            let beforeStart = text.substring(Math.max(0, start - prefix.length), start);
            let afterEnd = text.substring(end, Math.min(text.length, end + suffix.length));

            if (beforeStart === prefix && afterEnd === suffix) {
                // Already wrapped - unwrap
                let newText = text.substring(0, start - prefix.length) + selectedText + text.substring(end + suffix.length);
                mdEditor.text = newText;
                mdEditor.select(start - prefix.length, end - prefix.length);
            } else if (selectedText.startsWith(prefix) && selectedText.endsWith(suffix)) {
                // Selection includes markers - remove them
                let unwrapped = selectedText.substring(prefix.length, selectedText.length - suffix.length);
                let newText = text.substring(0, start) + unwrapped + text.substring(end);
                mdEditor.text = newText;
                mdEditor.select(start, start + unwrapped.length);
            } else {
                // Wrap selection
                let newText = text.substring(0, start) + prefix + selectedText + suffix + text.substring(end);
                mdEditor.text = newText;
                mdEditor.select(start + prefix.length, end + prefix.length);
            }
        }
        mdEditor.forceActiveFocus();
    }

    function mdToggleBold() {
        mdWrapSelection("**", "**");
    }

    function mdToggleItalic() {
        mdWrapSelection("*", "*");
    }

    function mdToggleUnderline() {
        mdWrapSelection("__", "__");
    }

    function mdToggleStrikethrough() {
        mdWrapSelection("~~", "~~");
    }

    function mdToggleCode() {
        mdWrapSelection("`", "`");
    }

    function mdInsertLink() {
        if (!mdEditor)
            return;

        let start = mdEditor.selectionStart;
        let end = mdEditor.selectionEnd;
        let text = mdEditor.text;

        if (start === end) {
            // No selection - insert link template
            let linkTemplate = "[text](url)";
            let newText = text.substring(0, start) + linkTemplate + text.substring(end);
            mdEditor.text = newText;
            // Select "text" for easy replacement
            mdEditor.select(start + 1, start + 5);
        } else {
            // Use selection as link text
            let selectedText = text.substring(start, end);
            let linkText = "[" + selectedText + "](url)";
            let newText = text.substring(0, start) + linkText + text.substring(end);
            mdEditor.text = newText;
            // Select "url" for easy replacement
            mdEditor.select(start + selectedText.length + 3, start + selectedText.length + 6);
        }
        mdEditor.forceActiveFocus();
    }

    // Get current line info
    function mdGetCurrentLine() {
        if (!mdEditor)
            return {
                start: 0,
                end: 0,
                text: "",
                lineNumber: 0
            };

        let text = mdEditor.text;
        let pos = mdEditor.cursorPosition;

        // Find line start
        let lineStart = pos;
        while (lineStart > 0 && text[lineStart - 1] !== '\n') {
            lineStart--;
        }

        // Find line end
        let lineEnd = pos;
        while (lineEnd < text.length && text[lineEnd] !== '\n') {
            lineEnd++;
        }

        return {
            start: lineStart,
            end: lineEnd,
            text: text.substring(lineStart, lineEnd)
        };
    }

    // Get heading level of current line (0 = no heading, 1-6 = H1-H6)
    function mdGetHeadingLevel(lineText) {
        let match = lineText.match(/^(#{1,6})\s/);
        if (match) {
            return match[1].length;
        }
        return 0;
    }

    // Update heading display
    function mdUpdateHeadingDisplay() {
        let line = mdGetCurrentLine();
        let level = mdGetHeadingLevel(line.text);
        mdCurrentHeading = level > 0 ? ("H" + level) : "P";
    }

    function mdSetHeadingLevel(level) {
        if (!mdEditor)
            return;

        let line = mdGetCurrentLine();
        let text = mdEditor.text;
        let currentLevel = mdGetHeadingLevel(line.text);

        // Remove existing heading markers
        let lineContent = line.text.replace(/^#{1,6}\s*/, '');

        // Add new heading markers
        let newLine;
        if (level === 0) {
            newLine = lineContent;
        } else {
            newLine = '#'.repeat(level) + ' ' + lineContent;
        }

        let newText = text.substring(0, line.start) + newLine + text.substring(line.end);
        let cursorOffset = level > 0 ? level + 1 : 0;

        mdEditor.text = newText;
        mdEditor.cursorPosition = line.start + cursorOffset + lineContent.length;
        mdUpdateHeadingDisplay();
        mdEditor.forceActiveFocus();
    }

    function mdIncreaseHeading() {
        let line = mdGetCurrentLine();
        let currentLevel = mdGetHeadingLevel(line.text);
        if (currentLevel < 6) {
            mdSetHeadingLevel(currentLevel + 1);
        }
    }

    function mdDecreaseHeading() {
        let line = mdGetCurrentLine();
        let currentLevel = mdGetHeadingLevel(line.text);
        if (currentLevel > 0) {
            mdSetHeadingLevel(currentLevel - 1);
        }
    }

    // Debounce timer for auto-save
    Timer {
        id: saveDebounceTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (currentNoteId && editorDirty) {
                saveCurrentNote();
            }
        }
    }

    Keys.onEscapePressed: {
        if (root.deleteMode) {
            root.cancelDeleteMode();
        } else if (root.renameMode) {
            root.cancelRenameMode();
        } else {
            Visibilities.setActiveModule("");
        }
    }

    onExpandedItemIndexChanged: {}

    function adjustScrollForExpandedItem(index) {
        if (index < 0 || index >= notesModel.count)
            return;

        var itemY = 0;
        for (var i = 0; i < index; i++) {
            itemY += 48;
        }

        // 3 options: Edit, Rename, Delete
        var listHeight = 36 * 3;
        var expandedHeight = 48 + 4 + listHeight + 8;

        var maxContentY = Math.max(0, resultsList.contentHeight - resultsList.height);
        var viewportTop = resultsList.contentY;
        var viewportBottom = viewportTop + resultsList.height;
        var itemBottom = itemY + expandedHeight;

        if (itemY < viewportTop) {
            resultsList.contentY = itemY;
        } else if (itemBottom > viewportBottom) {
            resultsList.contentY = Math.min(itemBottom - resultsList.height, maxContentY);
        }
    }

    onSelectedIndexChanged: {
        if (selectedIndex === -1 && resultsList.count > 0) {
            resultsList.positionViewAtIndex(0, ListView.Beginning);
        }

        if (expandedItemIndex >= 0 && selectedIndex !== expandedItemIndex) {
            expandedItemIndex = -1;
            selectedOptionIndex = 0;
            keyboardNavigation = false;
        }

        // Load note content when selection changes
        if (selectedIndex >= 0 && selectedIndex < filteredNotes.length) {
            let note = filteredNotes[selectedIndex];
            if (note && !note.isCreateButton) {
                loadNoteContent(note.id);
            } else {
                currentNoteId = "";
                currentNoteContent = "";
                currentNoteTitle = "";
            }
        } else {
            currentNoteId = "";
            currentNoteContent = "";
            currentNoteTitle = "";
        }
    }

    onSearchTextChanged: {
        updateFilteredNotes();
    }

    function clearSearch() {
        searchText = "";
        selectedIndex = -1;
        searchInput.focusInput();
        updateFilteredNotes();
    }

    function focusSearchInput() {
        searchInput.focusInput();
    }

    function cancelDeleteModeFromExternal() {
        if (deleteMode) {
            cancelDeleteMode();
        }
        if (renameMode) {
            cancelRenameMode();
        }
    }

    function updateFilteredNotes() {
        var newFilteredNotes = [];

        var createButtonText = "Create new note";
        var isCreateSpecific = false;
        var noteNameToCreate = "";

        if (searchText.length === 0) {
            newFilteredNotes = allNotes.slice();
        } else {
            newFilteredNotes = NotesUtils.filterNotes(allNotes, searchText);

            let exactMatch = allNotes.find(function (note) {
                return note.title.toLowerCase() === searchText.toLowerCase();
            });

            if (!exactMatch && searchText.length > 0) {
                createButtonText = `Create note "${searchText}"`;
                isCreateSpecific = true;
                noteNameToCreate = searchText;
            }
        }

        if (!deleteMode && !renameMode) {
            newFilteredNotes.unshift({
                id: "__create__",
                title: createButtonText,
                isCreateButton: true,
                isCreateSpecificButton: isCreateSpecific,
                noteNameToCreate: noteNameToCreate,
                icon: "plus"
            });
        }

        filteredNotes = newFilteredNotes;
        resultsList.enableScrollAnimation = false;
        resultsList.contentY = 0;

        notesModel.clear();
        for (var i = 0; i < newFilteredNotes.length; i++) {
            var note = newFilteredNotes[i];
            notesModel.append({
                noteId: note.id,
                noteData: note
            });
        }

        Qt.callLater(() => {
            resultsList.enableScrollAnimation = true;
        });

        if (!deleteMode && !renameMode) {
            if (searchText.length > 0 && newFilteredNotes.length > 0) {
                selectedIndex = 0;
                resultsList.currentIndex = 0;
            } else if (searchText.length === 0) {
                selectedIndex = -1;
                resultsList.currentIndex = -1;
            }
        }

        if (pendingRenamedNote !== "") {
            for (let i = 0; i < newFilteredNotes.length; i++) {
                if (newFilteredNotes[i].id === pendingRenamedNote) {
                    selectedIndex = i;
                    resultsList.currentIndex = i;
                    pendingRenamedNote = "";
                    break;
                }
            }
            if (pendingRenamedNote !== "") {
                pendingRenamedNote = "";
            }
        }
    }

    function enterDeleteMode(noteId) {
        originalSelectedIndex = selectedIndex;
        deleteMode = true;
        noteToDelete = noteId;
        deleteButtonIndex = 0;
        root.forceActiveFocus();
    }

    function cancelDeleteMode() {
        deleteMode = false;
        noteToDelete = "";
        deleteButtonIndex = 0;
        searchInput.focusInput();
        updateFilteredNotes();
        selectedIndex = originalSelectedIndex;
        resultsList.currentIndex = originalSelectedIndex;
        originalSelectedIndex = -1;
    }

    function confirmDeleteNote() {
        if (noteToDelete) {
            // Find if note is markdown to use correct extension
            var isMarkdown = false;
            for (var i = 0; i < allNotes.length; i++) {
                if (allNotes[i].id === noteToDelete) {
                    isMarkdown = allNotes[i].isMarkdown || false;
                    break;
                }
            }
            var extension = isMarkdown ? ".md" : noteExtension;
            // Store the ID before cancelDeleteMode clears it
            deleteNoteProcess.deletedNoteId = noteToDelete;
            deleteNoteProcess.command = ["rm", "-f", notesPath + "/" + noteToDelete + extension];
            deleteNoteProcess.running = true;
        }
        cancelDeleteMode();
    }

    function enterRenameMode(noteId) {
        renameSelectedIndex = selectedIndex;
        renameMode = true;
        noteToRename = noteId;

        // Find current title
        for (var i = 0; i < allNotes.length; i++) {
            if (allNotes[i].id === noteId) {
                newNoteName = allNotes[i].title;
                break;
            }
        }

        renameButtonIndex = 1;
        root.forceActiveFocus();
    }

    function cancelRenameMode() {
        renameMode = false;
        noteToRename = "";
        newNoteName = "";
        renameButtonIndex = 1;
        if (pendingRenamedNote === "") {
            searchInput.focusInput();
            updateFilteredNotes();
            selectedIndex = renameSelectedIndex;
            resultsList.currentIndex = renameSelectedIndex;
        } else {
            searchInput.focusInput();
        }
        renameSelectedIndex = -1;
    }

    function confirmRenameNote() {
        if (newNoteName.trim() !== "" && noteToRename) {
            pendingRenamedNote = noteToRename;
            updateNoteTitle(noteToRename, newNoteName.trim());
        }
        cancelRenameMode();
    }

    function createNewNote(title, isMarkdown) {
        var noteId = NotesUtils.generateUUID();
        var noteTitle = title || "Untitled Note";
        var extension = isMarkdown ? ".md" : noteExtension;

        // Create the note file with appropriate content
        var initialContent = isMarkdown ? "# " + noteTitle + "\n\n" : "<h1>" + noteTitle + "</h1><p></p>";

        createNoteProcess.noteId = noteId;
        createNoteProcess.noteTitle = noteTitle;
        createNoteProcess.noteIsMarkdown = isMarkdown || false;
        createNoteProcess.command = ["sh", "-c", "mkdir -p '" + notesPath + "' && printf '%s' '" + initialContent.replace(/'/g, "'\\''") + "' > '" + notesPath + "/" + noteId + extension + "'"];
        createNoteProcess.running = true;
    }

    function loadNoteContent(noteId) {
        if (!noteId || noteId === "__create__")
            return;

        // Save current note before loading new one
        if (currentNoteId && editorDirty) {
            saveCurrentNote();
        }

        // Find note to get isMarkdown flag
        var isMarkdown = false;
        for (var i = 0; i < allNotes.length; i++) {
            if (allNotes[i].id === noteId) {
                isMarkdown = allNotes[i].isMarkdown || false;
                break;
            }
        }

        loadingNote = true;
        currentNoteId = noteId;
        currentNoteIsMarkdown = isMarkdown;

        var extension = isMarkdown ? ".md" : noteExtension;
        readNoteProcess.command = ["cat", notesPath + "/" + noteId + extension];
        readNoteProcess.running = true;
    }

    function saveCurrentNote() {
        if (!currentNoteId || currentNoteId === "__create__")
            return;

        var extension = currentNoteIsMarkdown ? ".md" : noteExtension;

        // Get the text content
        var content = currentNoteIsMarkdown ? mdEditor.text : noteEditor.text;
        saveNoteProcess.command = ["sh", "-c", "printf '%s' '" + content.replace(/'/g, "'\\''") + "' > '" + notesPath + "/" + currentNoteId + extension + "'"];
        saveNoteProcess.running = true;
        editorDirty = false;

        // Update modified timestamp
        updateNoteModified(currentNoteId);
    }

    function updateNoteTitle(noteId, newTitle) {
        // Read index, update title, save
        readIndexForUpdateProcess.noteId = noteId;
        readIndexForUpdateProcess.newTitle = newTitle;
        readIndexForUpdateProcess.command = ["cat", indexPath];
        readIndexForUpdateProcess.running = true;
    }

    function updateNoteModified(noteId) {
        readIndexForModifiedProcess.noteId = noteId;
        readIndexForModifiedProcess.command = ["cat", indexPath];
        readIndexForModifiedProcess.running = true;
    }

    function refreshNotes() {
        readIndexProcess.running = true;
    }

    function openNoteInEditor(noteId) {
        // Select the note and focus editor
        var isMarkdown = false;
        for (var i = 0; i < filteredNotes.length; i++) {
            if (filteredNotes[i].id === noteId) {
                selectedIndex = i;
                resultsList.currentIndex = i;
                isMarkdown = filteredNotes[i].isMarkdown || false;
                break;
            }
        }
        Qt.callLater(() => {
            if (isMarkdown) {
                mdEditor.forceActiveFocus();
            } else {
                noteEditor.forceActiveFocus();
            }
        });
    }

    // Move note up/down in order
    function moveNoteUp() {
        if (selectedIndex <= 1)
            return; // Can't move create button or first note

        let note = filteredNotes[selectedIndex];
        if (note.isCreateButton)
            return;

        // Find in allNotes and swap
        let noteIdx = -1;
        for (let i = 0; i < allNotes.length; i++) {
            if (allNotes[i].id === note.id) {
                noteIdx = i;
                break;
            }
        }

        if (noteIdx > 0) {
            allNotes = NotesUtils.moveArrayItem(allNotes, noteIdx, noteIdx - 1);
            saveNotesOrder();
            updateFilteredNotes();
            selectedIndex = selectedIndex - 1;
            resultsList.currentIndex = selectedIndex;
        }
    }

    function moveNoteDown() {
        if (selectedIndex < 1 || selectedIndex >= filteredNotes.length - 1)
            return;

        let note = filteredNotes[selectedIndex];
        if (note.isCreateButton)
            return;

        let noteIdx = -1;
        for (let i = 0; i < allNotes.length; i++) {
            if (allNotes[i].id === note.id) {
                noteIdx = i;
                break;
            }
        }

        if (noteIdx >= 0 && noteIdx < allNotes.length - 1) {
            allNotes = NotesUtils.moveArrayItem(allNotes, noteIdx, noteIdx + 1);
            saveNotesOrder();
            updateFilteredNotes();
            selectedIndex = selectedIndex + 1;
            resultsList.currentIndex = selectedIndex;
        }
    }

    function saveNotesOrder() {
        var indexData = {
            order: allNotes.map(n => n.id),
            notes: {}
        };
        for (var i = 0; i < allNotes.length; i++) {
            var note = allNotes[i];
            indexData.notes[note.id] = {
                title: note.title,
                created: note.created,
                modified: note.modified,
                isMarkdown: note.isMarkdown || false
            };
        }
        var jsonContent = NotesUtils.serializeIndex(indexData);
        saveIndexProcess.command = ["sh", "-c", "printf '%s' '" + jsonContent.replace(/'/g, "'\\''") + "' > '" + indexPath + "'"];
        saveIndexProcess.running = true;
    }

    Component.onCompleted: {
        initDirProcess.running = true;
    }

    // --- Processes ---

    // Initialize directories
    Process {
        id: initDirProcess
        command: ["sh", "-c", "mkdir -p '" + notesPath + "' && touch '" + indexPath + "'"]

        onExited: code => {
            refreshNotes();
        }
    }

    // Read index.json
    Process {
        id: readIndexProcess
        command: ["cat", indexPath]
        stdout: SplitParser {
            onRead: data => readIndexProcess.stdoutData += data + "\n"
        }
        property string stdoutData: ""

        onExited: code => {
            var indexData = NotesUtils.parseIndex(stdoutData.trim());
            stdoutData = "";

            var loadedNotes = [];
            for (var i = 0; i < indexData.order.length; i++) {
                var noteId = indexData.order[i];
                var noteMeta = indexData.notes[noteId];
                if (noteMeta) {
                    loadedNotes.push({
                        id: noteId,
                        title: noteMeta.title || "Untitled",
                        created: noteMeta.created || "",
                        modified: noteMeta.modified || "",
                        isMarkdown: noteMeta.isMarkdown || false,
                        isCreateButton: false
                    });
                }
            }

            allNotes = loadedNotes;
            updateFilteredNotes();
        }
    }

    // Create note
    Process {
        id: createNoteProcess
        property string noteId: ""
        property string noteTitle: ""
        property bool noteIsMarkdown: false

        onExited: code => {
            if (code === 0) {
                // Add to allNotes and save index
                var newNote = {
                    id: noteId,
                    title: noteTitle,
                    created: NotesUtils.getCurrentTimestamp(),
                    modified: NotesUtils.getCurrentTimestamp(),
                    isMarkdown: noteIsMarkdown,
                    isCreateButton: false
                };
                allNotes.unshift(newNote);
                saveNotesOrder();
                updateFilteredNotes();

                // Select the new note
                pendingRenamedNote = noteId;
                updateFilteredNotes();

                // Focus the editor
                Qt.callLater(() => {
                    openNoteInEditor(noteId);
                });
            }
            noteId = "";
            noteTitle = "";
            noteIsMarkdown = false;
        }
    }

    // Delete note and update index
    Process {
        id: deleteNoteProcess
        property string deletedNoteId: ""

        onExited: code => {
            if (code === 0 && deletedNoteId !== "") {
                // Remove from allNotes
                allNotes = allNotes.filter(n => n.id !== deletedNoteId);
                saveNotesOrder();

                if (currentNoteId === deletedNoteId) {
                    currentNoteId = "";
                    currentNoteContent = "";
                    currentNoteTitle = "";
                }

                updateFilteredNotes();
                deletedNoteId = "";
            }
        }
    }

    // Read note content
    Process {
        id: readNoteProcess
        stdout: SplitParser {
            onRead: data => readNoteProcess.stdoutData += data + "\n"
        }
        property string stdoutData: ""

        onExited: code => {
            if (code === 0) {
                // Remove trailing newline added by parser
                currentNoteContent = stdoutData.replace(/\n$/, '');

                // Find title
                for (var i = 0; i < allNotes.length; i++) {
                    if (allNotes[i].id === currentNoteId) {
                        currentNoteTitle = allNotes[i].title;
                        break;
                    }
                }
            } else {
                currentNoteContent = "";
                currentNoteTitle = "";
            }
            stdoutData = "";
            editorDirty = false;
            loadingNote = false;
        }
    }

    // Save note content
    Process {
        id: saveNoteProcess
        onExited: code => {}
    }

    // Save index
    Process {
        id: saveIndexProcess
        onExited: code => {}
    }

    // Read index for title update
    Process {
        id: readIndexForUpdateProcess
        property string noteId: ""
        property string newTitle: ""
        stdout: SplitParser {
            onRead: data => readIndexForUpdateProcess.stdoutData += data + "\n"
        }
        property string stdoutData: ""

        onExited: code => {
            var indexData = NotesUtils.parseIndex(stdoutData.trim());
            stdoutData = "";

            if (indexData.notes[noteId]) {
                indexData.notes[noteId].title = newTitle;
                indexData.notes[noteId].modified = NotesUtils.getCurrentTimestamp();
            }

            // Update local allNotes
            for (var i = 0; i < allNotes.length; i++) {
                if (allNotes[i].id === noteId) {
                    allNotes[i].title = newTitle;
                    allNotes[i].modified = NotesUtils.getCurrentTimestamp();
                    break;
                }
            }

            var jsonContent = NotesUtils.serializeIndex(indexData);
            saveIndexProcess.command = ["sh", "-c", "printf '%s' '" + jsonContent.replace(/'/g, "'\\''") + "' > '" + indexPath + "'"];
            saveIndexProcess.running = true;

            updateFilteredNotes();
            noteId = "";
            newTitle = "";
        }
    }

    // Read index for modified timestamp update
    Process {
        id: readIndexForModifiedProcess
        property string noteId: ""
        stdout: SplitParser {
            onRead: data => readIndexForModifiedProcess.stdoutData += data + "\n"
        }
        property string stdoutData: ""

        onExited: code => {
            var indexData = NotesUtils.parseIndex(stdoutData.trim());
            stdoutData = "";

            if (indexData.notes[noteId]) {
                indexData.notes[noteId].modified = NotesUtils.getCurrentTimestamp();
            }

            var jsonContent = NotesUtils.serializeIndex(indexData);
            saveIndexProcess.command = ["sh", "-c", "printf '%s' '" + jsonContent.replace(/'/g, "'\\''") + "' > '" + indexPath + "'"];
            saveIndexProcess.running = true;
            noteId = "";
        }
    }

    implicitWidth: 400
    implicitHeight: 392

    RowLayout {
        id: mainLayout
        anchors.fill: parent
        spacing: 8

        // Left panel: Notes list
        Item {
            Layout.preferredWidth: root.leftPanelWidth
            Layout.fillHeight: true

            // Search input
            SearchInput {
                id: searchInput
                width: parent.width
                height: 48
                anchors.top: parent.top
                text: root.searchText
                placeholderText: "Search notes..."
                prefixIcon: root.prefixIcon
                handleTabNavigation: true

                onSearchTextChanged: text => {
                    root.searchText = text;
                }

                onBackspaceOnEmpty: {
                    root.backspaceOnEmpty();
                }

                onAccepted: {
                    if (root.deleteMode) {
                        if (root.deleteButtonIndex === 1) {
                            root.confirmDeleteNote();
                        } else {
                            root.cancelDeleteMode();
                        }
                        return;
                    }

                    if (root.renameMode) {
                        if (root.renameButtonIndex === 1) {
                            root.confirmRenameNote();
                        } else {
                            root.cancelRenameMode();
                        }
                        return;
                    }

                    if (root.expandedItemIndex >= 0) {
                        let note = filteredNotes[root.expandedItemIndex];
                        if (note) {
                            if (note.isCreateButton) {
                                // Create menu options
                                let createOptions = [function () {
                                        createNewNote(note.noteNameToCreate || "", false);
                                    }  // Rich Text
                                    , function () {
                                        createNewNote(note.noteNameToCreate || "", true);
                                    }    // Markdown
                                ];
                                if (root.selectedOptionIndex >= 0 && root.selectedOptionIndex < createOptions.length) {
                                    root.expandedItemIndex = -1;
                                    createOptions[root.selectedOptionIndex]();
                                }
                            } else {
                                // Note options
                                let options = [function () {
                                        openNoteInEditor(note.id);
                                    }, function () {
                                        enterRenameMode(note.id);
                                    }, function () {
                                        enterDeleteMode(note.id);
                                    }];
                                if (root.selectedOptionIndex >= 0 && root.selectedOptionIndex < options.length) {
                                    options[root.selectedOptionIndex]();
                                }
                            }
                        }
                        root.expandedItemIndex = -1;
                        root.selectedOptionIndex = 0;
                        return;
                    }

                    if (root.selectedIndex >= 0 && root.selectedIndex < filteredNotes.length) {
                        let note = filteredNotes[root.selectedIndex];
                        if (note.isCreateButton || note.isCreateSpecificButton) {
                            // Expand to show create options instead of creating directly
                            root.expandedItemIndex = root.selectedIndex;
                            root.selectedOptionIndex = 0;
                            root.keyboardNavigation = true;
                        } else {
                            openNoteInEditor(note.id);
                        }
                    }
                }

                onShiftAccepted: {
                    if (root.selectedIndex >= 0 && root.selectedIndex < filteredNotes.length) {
                        let note = filteredNotes[root.selectedIndex];
                        // Allow expanding both create button and regular notes
                        if (root.expandedItemIndex === root.selectedIndex) {
                            root.expandedItemIndex = -1;
                            root.selectedOptionIndex = 0;
                            root.keyboardNavigation = false;
                        } else {
                            root.expandedItemIndex = root.selectedIndex;
                            root.selectedOptionIndex = 0;
                            root.keyboardNavigation = true;
                        }
                    }
                }

                onCtrlRPressed: {
                    // Ctrl+R: Enter rename mode for selected note
                    if (root.selectedIndex >= 0 && root.selectedIndex < filteredNotes.length) {
                        let note = filteredNotes[root.selectedIndex];
                        if (!note.isCreateButton && !root.deleteMode && !root.renameMode) {
                            enterRenameMode(note.id);
                        }
                    }
                }

                onEscapePressed: {
                    if (root.deleteMode) {
                        root.cancelDeleteMode();
                    } else if (root.renameMode) {
                        root.cancelRenameMode();
                    } else if (root.expandedItemIndex >= 0) {
                        root.expandedItemIndex = -1;
                        root.selectedOptionIndex = 0;
                        root.keyboardNavigation = false;
                    } else {
                        Visibilities.setActiveModule("");
                    }
                }

                onDownPressed: {
                    if (root.deleteMode) {
                        return;
                    }
                    if (root.renameMode) {
                        return;
                    }
                    if (root.expandedItemIndex >= 0) {
                        // Max options: 2 for create button, 3 for notes
                        var isCreateBtn = root.expandedItemIndex < filteredNotes.length && filteredNotes[root.expandedItemIndex].isCreateButton;
                        var maxIndex = isCreateBtn ? 1 : 2;
                        if (root.selectedOptionIndex < maxIndex) {
                            root.selectedOptionIndex++;
                            root.keyboardNavigation = true;
                        }
                    } else if (resultsList.count > 0) {
                        if (root.selectedIndex === -1) {
                            root.selectedIndex = 0;
                            resultsList.currentIndex = 0;
                        } else if (root.selectedIndex < resultsList.count - 1) {
                            root.selectedIndex++;
                            resultsList.currentIndex = root.selectedIndex;
                        }
                    }
                }

                onUpPressed: {
                    if (root.deleteMode) {
                        return;
                    }
                    if (root.renameMode) {
                        return;
                    }
                    if (root.expandedItemIndex >= 0) {
                        if (root.selectedOptionIndex > 0) {
                            root.selectedOptionIndex--;
                            root.keyboardNavigation = true;
                        }
                    } else if (root.selectedIndex > 0) {
                        root.selectedIndex--;
                        resultsList.currentIndex = root.selectedIndex;
                    } else if (root.selectedIndex === 0 && root.searchText.length === 0) {
                        root.selectedIndex = -1;
                        resultsList.currentIndex = -1;
                    }
                }

                onCtrlUpPressed: {
                    root.moveNoteUp();
                }

                onCtrlDownPressed: {
                    root.moveNoteDown();
                }

                onTabPressed: {
                    // Focus editor when pressing Tab
                    if (currentNoteId) {
                        if (currentNoteIsMarkdown) {
                            mdEditor.forceActiveFocus();
                        } else {
                            noteEditor.forceActiveFocus();
                        }
                    }
                }
            }

            // Results list
            ListView {
                id: resultsList
                width: parent.width
                anchors.top: searchInput.bottom
                anchors.bottom: parent.bottom
                anchors.topMargin: 8
                clip: true
                model: notesModel
                currentIndex: root.selectedIndex
                spacing: 0
                interactive: !root.deleteMode && !root.renameMode && root.expandedItemIndex === -1

                property bool enableScrollAnimation: true

                Behavior on contentY {
                    enabled: resultsList.enableScrollAnimation && Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutCubic
                    }
                }

                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && currentIndex < count) {
                        positionViewAtIndex(currentIndex, ListView.Contain);
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    active: true
                }

                highlight: Item {
                    width: resultsList.width
                    height: {
                        let baseHeight = 48;
                        if (resultsList.currentIndex === root.expandedItemIndex && !root.deleteMode && !root.renameMode) {
                            // Check if current item is create button
                            var isCreateBtn = resultsList.currentIndex >= 0 && resultsList.currentIndex < filteredNotes.length && filteredNotes[resultsList.currentIndex].isCreateButton;
                            var optionCount = isCreateBtn ? 2 : 3;
                            var listHeight = 36 * optionCount;
                            return baseHeight + 4 + listHeight + 8;
                        }
                        return baseHeight;
                    }

                    y: {
                        var yPos = 0;
                        for (var i = 0; i < resultsList.currentIndex && i < notesModel.count; i++) {
                            var itemHeight = 48;
                            if (i === root.expandedItemIndex && !root.deleteMode && !root.renameMode) {
                                var isCreateBtn = i < filteredNotes.length && filteredNotes[i].isCreateButton;
                                var optionCount = isCreateBtn ? 2 : 3;
                                var listHeight = 36 * optionCount;
                                itemHeight = 48 + 4 + listHeight + 8;
                            }
                            yPos += itemHeight;
                        }
                        return yPos;
                    }

                    Behavior on y {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on height {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutQuart
                        }
                    }

                    onHeightChanged: {
                        if (root.expandedItemIndex >= 0 && height > 48) {
                            Qt.callLater(() => {
                                root.adjustScrollForExpandedItem(root.expandedItemIndex);
                            });
                        }
                    }

                    StyledRect {
                        anchors.fill: parent
                        variant: {
                            if (root.deleteMode) {
                                return "error";
                            } else if (root.renameMode) {
                                return "secondary";
                            } else if (root.expandedItemIndex >= 0 && root.selectedIndex === root.expandedItemIndex) {
                                return "pane";
                            } else {
                                return "primary";
                            }
                        }
                        radius: Styling.radius(4)
                        visible: root.selectedIndex >= 0

                        Behavior on color {
                            enabled: Config.animDuration > 0
                            ColorAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Easing.OutQuart
                            }
                        }
                    }
                }

                highlightFollowsCurrentItem: false

                delegate: Rectangle {
                    required property string noteId
                    required property var noteData
                    required property int index

                    property var modelData: noteData

                    width: resultsList.width
                    height: {
                        let baseHeight = 48;
                        if (index === root.expandedItemIndex && !isInDeleteMode && !isInRenameMode) {
                            // 2 options for create button, 3 for regular notes
                            var optionCount = modelData.isCreateButton ? 2 : 3;
                            var listHeight = 36 * optionCount;
                            return baseHeight + 4 + listHeight + 8;
                        }
                        return baseHeight;
                    }
                    color: "transparent"
                    radius: 16

                    Behavior on height {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutQuart
                        }
                    }

                    property bool isInDeleteMode: root.deleteMode && modelData.id === root.noteToDelete
                    property bool isInRenameMode: root.renameMode && modelData.id === root.noteToRename
                    property bool isSelected: root.selectedIndex === index
                    property bool isExpanded: index === root.expandedItemIndex
                    property color textColor: {
                        if (isInDeleteMode) {
                            return Styling.srItem("error");
                        } else if (isExpanded) {
                            return Styling.srItem("pane");
                        } else if (isSelected) {
                            return Styling.srItem("primary");
                        } else {
                            return Colors.overSurface;
                        }
                    }
                    property string displayText: {
                        if (isInDeleteMode) {
                            return "Delete \"" + modelData.title.substring(0, 20) + (modelData.title.length > 20 ? '...' : '') + "\"?";
                        }
                        return modelData.title || "Untitled";
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: isExpanded ? 48 : parent.height
                        hoverEnabled: true
                        enabled: !root.deleteMode && !root.renameMode
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onEntered: {
                            if (!root.deleteMode && root.expandedItemIndex === -1) {
                                root.selectedIndex = index;
                                resultsList.currentIndex = index;
                            }
                        }

                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton && !isInDeleteMode) {
                                if (root.deleteMode && modelData.id !== root.noteToDelete) {
                                    root.cancelDeleteMode();
                                    return;
                                }

                                if (!root.deleteMode && !isExpanded) {
                                    if (modelData.isCreateButton || modelData.isCreateSpecificButton) {
                                        // Show create menu instead of creating directly
                                        if (root.expandedItemIndex === index) {
                                            root.expandedItemIndex = -1;
                                            root.selectedOptionIndex = 0;
                                            root.keyboardNavigation = false;
                                        } else {
                                            root.expandedItemIndex = index;
                                            root.selectedIndex = index;
                                            resultsList.currentIndex = index;
                                            root.selectedOptionIndex = 0;
                                            root.keyboardNavigation = true;
                                        }
                                    } else {
                                        openNoteInEditor(modelData.id);
                                    }
                                }
                            } else if (mouse.button === Qt.RightButton) {
                                if (root.deleteMode) {
                                    root.cancelDeleteMode();
                                    return;
                                }

                                if (modelData.isCreateButton)
                                    return;

                                if (root.expandedItemIndex === index) {
                                    root.expandedItemIndex = -1;
                                    root.selectedOptionIndex = 0;
                                    root.keyboardNavigation = false;
                                    root.selectedIndex = index;
                                    resultsList.currentIndex = index;
                                } else {
                                    root.expandedItemIndex = index;
                                    root.selectedIndex = index;
                                    resultsList.currentIndex = index;
                                    root.selectedOptionIndex = 0;
                                    root.keyboardNavigation = false;
                                }
                            }
                        }

                        // Delete buttons
                        Rectangle {
                            id: actionContainer
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.rightMargin: 8
                            width: 68
                            height: 32
                            color: "transparent"
                            opacity: isInDeleteMode ? 1.0 : 0.0
                            visible: opacity > 0

                            transform: Translate {
                                x: isInDeleteMode ? 0 : 80

                                Behavior on x {
                                    enabled: Config.animDuration > 0
                                    NumberAnimation {
                                        duration: Config.animDuration
                                        easing.type: Easing.OutQuart
                                    }
                                }
                            }

                            Behavior on opacity {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration / 2
                                    easing.type: Easing.OutQuart
                                }
                            }

                            StyledRect {
                                id: deleteHighlight
                                variant: "overerror"
                                radius: Styling.radius(-4)
                                visible: isInDeleteMode
                                z: 0

                                property real activeButtonMargin: 2
                                property real idx1X: root.deleteButtonIndex
                                property real idx2X: root.deleteButtonIndex

                                x: {
                                    let minX = Math.min(idx1X, idx2X) * 36 + activeButtonMargin;
                                    return minX;
                                }

                                y: activeButtonMargin

                                width: {
                                    let stretchX = Math.abs(idx1X - idx2X) * 36 + 32 - activeButtonMargin * 2;
                                    return stretchX;
                                }

                                height: 32 - activeButtonMargin * 2

                                Behavior on idx1X {
                                    enabled: Config.animDuration > 0
                                    NumberAnimation {
                                        duration: Config.animDuration / 3
                                        easing.type: Easing.OutSine
                                    }
                                }
                                Behavior on idx2X {
                                    enabled: Config.animDuration > 0
                                    NumberAnimation {
                                        duration: Config.animDuration
                                        easing.type: Easing.OutSine
                                    }
                                }
                            }

                            Row {
                                id: actionButtons
                                anchors.fill: parent
                                spacing: 4

                                Rectangle {
                                    width: 32
                                    height: 32
                                    color: "transparent"
                                    radius: 6
                                    z: 1

                                    property bool isHighlighted: root.deleteButtonIndex === 0

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: root.cancelDeleteMode()
                                        onEntered: root.deleteButtonIndex = 0
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.cancel
                                        color: parent.isHighlighted ? Colors.overErrorContainer : Colors.overError
                                        font.pixelSize: 14
                                        font.family: Icons.font
                                        textFormat: Text.RichText

                                        Behavior on color {
                                            enabled: Config.animDuration > 0
                                            ColorAnimation {
                                                duration: Config.animDuration / 2
                                                easing.type: Easing.OutQuart
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 32
                                    height: 32
                                    color: "transparent"
                                    radius: 6
                                    z: 1

                                    property bool isHighlighted: root.deleteButtonIndex === 1

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: root.confirmDeleteNote()
                                        onEntered: root.deleteButtonIndex = 1
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.accept
                                        color: parent.isHighlighted ? Colors.overErrorContainer : Colors.overError
                                        font.pixelSize: 14
                                        font.family: Icons.font
                                        textFormat: Text.RichText

                                        Behavior on color {
                                            enabled: Config.animDuration > 0
                                            ColorAnimation {
                                                duration: Config.animDuration / 2
                                                easing.type: Easing.OutQuart
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Item content
                    RowLayout {
                        id: mainContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        anchors.rightMargin: isInRenameMode ? 84 : 8
                        height: 32
                        spacing: 8

                        Behavior on anchors.rightMargin {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: Config.animDuration
                                easing.type: Easing.OutQuart
                            }
                        }

                        StyledRect {
                            id: iconBackground
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            Layout.alignment: Qt.AlignVCenter
                            variant: {
                                if (isInDeleteMode) {
                                    return "overerror";
                                } else if (isInRenameMode) {
                                    return "oversecondary";
                                } else if (root.selectedIndex === index) {
                                    return "overprimary";
                                } else if (modelData.isCreateButton) {
                                    return "primary";
                                } else {
                                    return "common";
                                }
                            }
                            radius: Styling.radius(-4)

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    if (isInDeleteMode) {
                                        return Icons.alert;
                                    } else if (isInRenameMode) {
                                        return Icons.edit;
                                    } else if (modelData.isCreateButton) {
                                        return Icons.plus;
                                    } else if (modelData.isMarkdown) {
                                        return Icons.markdown;
                                    } else {
                                        return Icons.file;
                                    }
                                }
                                color: iconBackground.item
                                font.family: Icons.font
                                font.pixelSize: 16
                                textFormat: Text.RichText
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            Loader {
                                Layout.fillWidth: true
                                sourceComponent: {
                                    if (root.renameMode && modelData.id === root.noteToRename) {
                                        return renameTextInput;
                                    } else {
                                        return normalText;
                                    }
                                }
                            }

                            Component {
                                id: normalText
                                Text {
                                    text: displayText
                                    font.family: Config.theme.font
                                    font.pixelSize: Config.theme.fontSize
                                    font.weight: isInDeleteMode ? Font.Bold : (isSelected ? Font.Bold : Font.Normal)
                                    color: textColor
                                    elide: Text.ElideRight

                                    Behavior on color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation {
                                            duration: Config.animDuration / 2
                                            easing.type: Easing.OutQuart
                                        }
                                    }
                                }
                            }

                            Component {
                                id: renameTextInput
                                TextField {
                                    text: root.newNoteName
                                    color: Colors.overSecondary
                                    selectionColor: Colors.overSecondary
                                    selectedTextColor: Colors.secondary
                                    font.family: Config.theme.font
                                    font.pixelSize: Config.theme.fontSize
                                    font.weight: Font.Bold
                                    background: Rectangle {
                                        color: "transparent"
                                        border.width: 0
                                    }
                                    selectByMouse: true

                                    onTextChanged: {
                                        root.newNoteName = text;
                                    }

                                    Component.onCompleted: {
                                        Qt.callLater(() => {
                                            forceActiveFocus();
                                            selectAll();
                                        });
                                    }

                                    Keys.onPressed: event => {
                                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                            root.confirmRenameNote();
                                            event.accepted = true;
                                        } else if (event.key === Qt.Key_Escape) {
                                            root.cancelRenameMode();
                                            event.accepted = true;
                                        } else if (event.key === Qt.Key_Left) {
                                            root.renameButtonIndex = 0;
                                            event.accepted = true;
                                        } else if (event.key === Qt.Key_Right) {
                                            root.renameButtonIndex = 1;
                                            event.accepted = true;
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.modified ? NotesUtils.formatTimestamp(modelData.modified) : ""
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize - 2
                                color: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.6)
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                visible: !modelData.isCreateButton && text !== "" && !isInRenameMode
                            }
                        }
                    }

                    // Rename action buttons (cancel/confirm)
                    Rectangle {
                        id: renameActionContainer
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: 8
                        anchors.topMargin: 8
                        width: 68
                        height: 32
                        color: "transparent"
                        opacity: isInRenameMode ? 1.0 : 0.0
                        visible: opacity > 0

                        transform: Translate {
                            x: isInRenameMode ? 0 : 80

                            Behavior on x {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutQuart
                                }
                            }
                        }

                        Behavior on opacity {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Easing.OutQuart
                            }
                        }

                        StyledRect {
                            id: renameHighlight
                            variant: "oversecondary"
                            radius: Styling.radius(-4)
                            visible: isInRenameMode
                            z: 0

                            property real activeButtonMargin: 2
                            property real idx1X: root.renameButtonIndex
                            property real idx2X: root.renameButtonIndex

                            x: {
                                let minX = Math.min(idx1X, idx2X) * 36 + activeButtonMargin;
                                return minX;
                            }

                            y: activeButtonMargin

                            width: {
                                let stretchX = Math.abs(idx1X - idx2X) * 36 + 32 - activeButtonMargin * 2;
                                return stretchX;
                            }

                            height: 32 - activeButtonMargin * 2

                            Behavior on idx1X {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration / 3
                                    easing.type: Easing.OutSine
                                }
                            }
                            Behavior on idx2X {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutSine
                                }
                            }
                        }

                        Row {
                            id: renameActionButtons
                            anchors.fill: parent
                            spacing: 4

                            Rectangle {
                                id: renameCancelButton
                                width: 32
                                height: 32
                                color: "transparent"
                                radius: 6
                                z: 1

                                property bool isHighlighted: root.renameButtonIndex === 0

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.cancelRenameMode()
                                    onEntered: root.renameButtonIndex = 0
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.cancel
                                    color: renameCancelButton.isHighlighted ? Colors.overSecondaryContainer : Colors.overSecondary
                                    font.pixelSize: 14
                                    font.family: Icons.font
                                    textFormat: Text.RichText

                                    Behavior on color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation {
                                            duration: Config.animDuration / 2
                                            easing.type: Easing.OutQuart
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: renameConfirmButton
                                width: 32
                                height: 32
                                color: "transparent"
                                radius: 6
                                z: 1

                                property bool isHighlighted: root.renameButtonIndex === 1

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.confirmRenameNote()
                                    onEntered: root.renameButtonIndex = 1
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.accept
                                    color: renameConfirmButton.isHighlighted ? Colors.overSecondaryContainer : Colors.overSecondary
                                    font.pixelSize: 14
                                    font.family: Icons.font
                                    textFormat: Text.RichText

                                    Behavior on color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation {
                                            duration: Config.animDuration / 2
                                            easing.type: Easing.OutQuart
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Expandable options list (matching TmuxTab styling)
                    RowLayout {
                        id: expandedOptionsLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        anchors.bottomMargin: 8
                        spacing: 4
                        visible: isExpanded && !isInDeleteMode && !isInRenameMode
                        opacity: (isExpanded && !isInDeleteMode && !isInRenameMode) ? 1 : 0

                        Behavior on opacity {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: Config.animDuration
                                easing.type: Easing.OutQuart
                            }
                        }

                        property var noteOptions: [
                            {
                                text: "Edit",
                                icon: Icons.edit,
                                highlightColor: Styling.srItem("overprimary"),
                                textColor: Styling.srItem("primary"),
                                action: function () {
                                    openNoteInEditor(modelData.id);
                                }
                            },
                            {
                                text: "Rename",
                                icon: Icons.edit,
                                highlightColor: Colors.secondary,
                                textColor: Styling.srItem("secondary"),
                                action: function () {
                                    enterRenameMode(modelData.id);
                                    root.expandedItemIndex = -1;
                                }
                            },
                            {
                                text: "Delete",
                                icon: Icons.trash,
                                highlightColor: Colors.error,
                                textColor: Styling.srItem("error"),
                                action: function () {
                                    enterDeleteMode(modelData.id);
                                    root.expandedItemIndex = -1;
                                }
                            }
                        ]

                        property var createOptions: [
                            {
                                text: "Rich Text",
                                icon: Icons.file,
                                highlightColor: Styling.srItem("overprimary"),
                                textColor: Styling.srItem("primary"),
                                action: function () {
                                    root.expandedItemIndex = -1;
                                    createNewNote(modelData.noteNameToCreate || "", false);
                                }
                            },
                            {
                                text: "Markdown",
                                icon: Icons.markdown,
                                highlightColor: Colors.secondary,
                                textColor: Styling.srItem("secondary"),
                                action: function () {
                                    root.expandedItemIndex = -1;
                                    createNewNote(modelData.noteNameToCreate || "", true);
                                }
                            }
                        ]

                        ClippingRectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36 * (modelData.isCreateButton ? 2 : 3)
                            color: Colors.background
                            radius: Styling.radius(0)

                            Behavior on Layout.preferredHeight {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutQuart
                                }
                            }

                            ListView {
                                id: optionsListView
                                anchors.fill: parent
                                clip: true
                                interactive: false
                                boundsBehavior: Flickable.StopAtBounds
                                model: modelData.isCreateButton ? expandedOptionsLayout.createOptions : expandedOptionsLayout.noteOptions
                                currentIndex: root.selectedOptionIndex
                                highlightFollowsCurrentItem: true
                                highlightRangeMode: ListView.ApplyRange
                                preferredHighlightBegin: 0
                                preferredHighlightEnd: height

                                highlight: StyledRect {
                                    variant: {
                                        if (optionsListView.currentIndex >= 0 && optionsListView.currentIndex < optionsListView.count) {
                                            var item = optionsListView.model[optionsListView.currentIndex];
                                            if (item && item.highlightColor) {
                                                if (item.highlightColor === Colors.error)
                                                    return "error";
                                                if (item.highlightColor === Colors.secondary)
                                                    return "secondary";
                                                return "primary";
                                            }
                                        }
                                        return "primary";
                                    }
                                    radius: Styling.radius(0)
                                    visible: optionsListView.currentIndex >= 0
                                    z: -1

                                    Behavior on opacity {
                                        enabled: Config.animDuration > 0
                                        NumberAnimation {
                                            duration: Config.animDuration / 2
                                            easing.type: Easing.OutQuart
                                        }
                                    }
                                }

                                highlightMoveDuration: Config.animDuration > 0 ? Config.animDuration / 2 : 0
                                highlightMoveVelocity: -1
                                highlightResizeDuration: Config.animDuration / 2
                                highlightResizeVelocity: -1

                                delegate: Item {
                                    required property var modelData
                                    required property int index

                                    property alias itemData: delegateData.modelData

                                    QtObject {
                                        id: delegateData
                                        property var modelData: parent ? parent.modelData : null
                                    }

                                    width: optionsListView.width
                                    height: 36

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 8

                                            Text {
                                                text: modelData && modelData.icon ? modelData.icon : ""
                                                font.family: Icons.font
                                                font.pixelSize: 14
                                                font.weight: Font.Bold
                                                textFormat: Text.RichText
                                                color: {
                                                    if (optionsListView.currentIndex === index && modelData && modelData.textColor) {
                                                        return modelData.textColor;
                                                    }
                                                    return Colors.overSurface;
                                                }

                                                Behavior on color {
                                                    enabled: Config.animDuration > 0
                                                    ColorAnimation {
                                                        duration: Config.animDuration / 2
                                                        easing.type: Easing.OutQuart
                                                    }
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData && modelData.text ? modelData.text : ""
                                                font.family: Config.theme.font
                                                font.pixelSize: Config.theme.fontSize
                                                font.weight: optionsListView.currentIndex === index ? Font.Bold : Font.Normal
                                                color: {
                                                    if (optionsListView.currentIndex === index && modelData && modelData.textColor) {
                                                        return modelData.textColor;
                                                    }
                                                    return Colors.overSurface;
                                                }
                                                elide: Text.ElideRight
                                                maximumLineCount: 1

                                                Behavior on color {
                                                    enabled: Config.animDuration > 0
                                                    ColorAnimation {
                                                        duration: Config.animDuration / 2
                                                        easing.type: Easing.OutQuart
                                                    }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            onEntered: {
                                                optionsListView.currentIndex = index;
                                                root.selectedOptionIndex = index;
                                                root.keyboardNavigation = false;
                                            }

                                            onClicked: {
                                                if (modelData && modelData.action) {
                                                    modelData.action();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Separator
        Separator {
            Layout.preferredWidth: 2
            Layout.fillHeight: true
            vert: true
        }

        // Right panel: WYSIWYG Editor (Rich Text mode)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            visible: currentNoteId !== "" && !currentNoteIsMarkdown

            // Formatting toolbar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 4

                    // Font size controls: minus button, input, plus button
                    Rectangle {
                        id: fontSizeMinusButton
                        width: 32
                        height: 32
                        radius: Styling.radius(-4)
                        color: "transparent"

                        property bool isHovered: minusMouseArea.containsMouse

                        StyledRect {
                            anchors.fill: parent
                            variant: parent.isHovered ? "surface" : "transparent"
                            radius: Styling.radius(-4)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: Icons.minus
                            font.family: Icons.font
                            font.pixelSize: 14
                            color: Colors.overSurface
                        }

                        MouseArea {
                            id: minusMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let currentSize = getCurrentFontSize();
                                let newSize = Math.max(8, currentSize - 2);
                                setFontSize(newSize);
                            }
                        }

                        StyledToolTip {
                            tooltipText: "Decrease font size (Alt+Down)"
                            visible: minusMouseArea.containsMouse
                        }
                    }

                    Rectangle {
                        id: fontSizeInput
                        width: 40
                        height: 32
                        radius: Styling.radius(-4)
                        color: "transparent"

                        StyledRect {
                            anchors.fill: parent
                            variant: fontSizeField.activeFocus ? "primary" : "surface"
                            radius: Styling.radius(-4)
                        }

                        TextInput {
                            id: fontSizeField
                            anchors.centerIn: parent
                            width: parent.width - 8
                            horizontalAlignment: TextInput.AlignHCenter
                            text: getCurrentFontSize().toString()
                            font.family: Config.theme.font
                            font.pixelSize: 14
                            color: activeFocus ? Colors.overPrimary : Colors.overSurface
                            selectByMouse: true
                            validator: IntValidator {
                                bottom: 8
                                top: 200
                            }

                            onEditingFinished: {
                                let size = parseInt(text);
                                if (!isNaN(size) && size >= 8 && size <= 200) {
                                    setFontSize(size);
                                } else {
                                    text = getCurrentFontSize().toString();
                                }
                                noteEditor.forceActiveFocus();
                            }

                            Keys.onEscapePressed: {
                                text = getCurrentFontSize().toString();
                                noteEditor.forceActiveFocus();
                            }
                        }
                    }

                    Rectangle {
                        id: fontSizePlusButton
                        width: 32
                        height: 32
                        radius: Styling.radius(-4)
                        color: "transparent"

                        property bool isHovered: plusMouseArea.containsMouse

                        StyledRect {
                            anchors.fill: parent
                            variant: parent.isHovered ? "surface" : "transparent"
                            radius: Styling.radius(-4)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: Icons.plus
                            font.family: Icons.font
                            font.pixelSize: 14
                            color: Colors.overSurface
                        }

                        MouseArea {
                            id: plusMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let currentSize = getCurrentFontSize();
                                let newSize = Math.min(200, currentSize + 2);
                                setFontSize(newSize);
                            }
                        }

                        StyledToolTip {
                            tooltipText: "Increase font size (Alt+Up)"
                            visible: plusMouseArea.containsMouse
                        }
                    }

                    // Separator
                    Rectangle {
                        width: 1
                        height: 24
                        color: Colors.outline
                        opacity: 0.3
                    }

                    // Bold button
                    Rectangle {
                        id: boldButton
                        width: 32
                        height: 32
                        radius: Styling.radius(-4)
                        color: isBold() ? Styling.srItem("overprimary") : "transparent"

                        property bool isHovered: boldMouseArea.containsMouse

                        StyledRect {
                            anchors.fill: parent
                            variant: parent.isHovered && !isBold() ? "surface" : "transparent"
                            radius: Styling.radius(-4)
                            visible: !isBold()
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "B"
                            font.family: Config.theme.font
                            font.pixelSize: 14
                            font.bold: true
                            color: isBold() ? Colors.overPrimary : Colors.overSurface
                        }

                        MouseArea {
                            id: boldMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: toggleBold()
                        }

                        StyledToolTip {
                            tooltipText: "Bold (Ctrl+B)"
                            visible: boldMouseArea.containsMouse
                        }
                    }

                    // Italic button
                    Rectangle {
                        id: italicButton
                        width: 32
                        height: 32
                        radius: Styling.radius(-4)
                        color: isItalic() ? Styling.srItem("overprimary") : "transparent"

                        property bool isHovered: italicMouseArea.containsMouse

                        StyledRect {
                            anchors.fill: parent
                            variant: parent.isHovered && !isItalic() ? "surface" : "transparent"
                            radius: Styling.radius(-4)
                            visible: !isItalic()
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "I"
                            font.family: Config.theme.font
                            font.pixelSize: 14
                            font.italic: true
                            color: isItalic() ? Colors.overPrimary : Colors.overSurface
                        }

                        MouseArea {
                            id: italicMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: toggleItalic()
                        }

                        StyledToolTip {
                            tooltipText: "Italic (Ctrl+I)"
                            visible: italicMouseArea.containsMouse
                        }
                    }

                    // Underline button
                    Rectangle {
                        id: underlineButton
                        width: 32
                        height: 32
                        radius: Styling.radius(-4)
                        color: isUnderline() ? Styling.srItem("overprimary") : "transparent"

                        property bool isHovered: underlineMouseArea.containsMouse

                        StyledRect {
                            anchors.fill: parent
                            variant: parent.isHovered && !isUnderline() ? "surface" : "transparent"
                            radius: Styling.radius(-4)
                            visible: !isUnderline()
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "U"
                            font.family: Config.theme.font
                            font.pixelSize: 14
                            font.underline: true
                            color: isUnderline() ? Colors.overPrimary : Colors.overSurface
                        }

                        MouseArea {
                            id: underlineMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: toggleUnderline()
                        }

                        StyledToolTip {
                            tooltipText: "Underline (Ctrl+U)"
                            visible: underlineMouseArea.containsMouse
                        }
                    }

                    // Strikethrough button
                    Rectangle {
                        id: strikeButton
                        width: 32
                        height: 32
                        radius: Styling.radius(-4)
                        color: isStrikeout() ? Styling.srItem("overprimary") : "transparent"

                        property bool isHovered: strikeMouseArea.containsMouse

                        StyledRect {
                            anchors.fill: parent
                            variant: parent.isHovered && !isStrikeout() ? "surface" : "transparent"
                            radius: Styling.radius(-4)
                            visible: !isStrikeout()
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "S"
                            font.family: Config.theme.font
                            font.pixelSize: 14
                            font.strikeout: true
                            color: isStrikeout() ? Colors.overPrimary : Colors.overSurface
                        }

                        MouseArea {
                            id: strikeMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: toggleStrikeout()
                        }

                        StyledToolTip {
                            tooltipText: "Strikethrough (Ctrl+D)"
                            visible: strikeMouseArea.containsMouse
                        }
                    }

                    // Separator
                    Rectangle {
                        width: 1
                        height: 24
                        color: Colors.outline
                        opacity: 0.3
                    }

                    // Align Left
                    Rectangle {
                        id: alignLeftButton
                        width: 32
                        height: 32
                        radius: Styling.radius(-4)
                        color: noteEditor.cursorSelection.alignment === Qt.AlignLeft ? Styling.srItem("overprimary") : "transparent"

                        property bool isHovered: alignLeftMouseArea.containsMouse

                        StyledRect {
                            anchors.fill: parent
                            variant: parent.isHovered && noteEditor.cursorSelection.alignment !== Qt.AlignLeft ? "surface" : "transparent"
                            radius: Styling.radius(-4)
                            visible: noteEditor.cursorSelection.alignment !== Qt.AlignLeft
                        }

                        Text {
                            anchors.centerIn: parent
                            text: Icons.alignLeft
                            font.family: Icons.font
                            font.pixelSize: 14
                            color: noteEditor.cursorSelection.alignment === Qt.AlignLeft ? Colors.overPrimary : Colors.overSurface
                        }

                        MouseArea {
                            id: alignLeftMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                noteEditor.cursorSelection.alignment = Qt.AlignLeft;
                                noteEditor.forceActiveFocus();
                            }
                        }

                        StyledToolTip {
                            tooltipText: "Align Left (Alt+Left)"
                            visible: alignLeftMouseArea.containsMouse
                        }
                    }

                    // Align Center
                    Rectangle {
                        id: alignCenterButton
                        width: 32
                        height: 32
                        radius: Styling.radius(-4)
                        color: noteEditor.cursorSelection.alignment === Qt.AlignHCenter ? Styling.srItem("overprimary") : "transparent"

                        property bool isHovered: alignCenterMouseArea.containsMouse

                        StyledRect {
                            anchors.fill: parent
                            variant: parent.isHovered && noteEditor.cursorSelection.alignment !== Qt.AlignHCenter ? "surface" : "transparent"
                            radius: Styling.radius(-4)
                            visible: noteEditor.cursorSelection.alignment !== Qt.AlignHCenter
                        }

                        Text {
                            anchors.centerIn: parent
                            text: Icons.alignCenter
                            font.family: Icons.font
                            font.pixelSize: 14
                            color: noteEditor.cursorSelection.alignment === Qt.AlignHCenter ? Colors.overPrimary : Colors.overSurface
                        }

                        MouseArea {
                            id: alignCenterMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                noteEditor.cursorSelection.alignment = Qt.AlignHCenter;
                                noteEditor.forceActiveFocus();
                            }
                        }

                        StyledToolTip {
                            tooltipText: "Align Center (Alt+Left/Right)"
                            visible: alignCenterMouseArea.containsMouse
                        }
                    }

                    // Align Right
                    Rectangle {
                        id: alignRightButton
                        width: 32
                        height: 32
                        radius: Styling.radius(-4)
                        color: noteEditor.cursorSelection.alignment === Qt.AlignRight ? Styling.srItem("overprimary") : "transparent"

                        property bool isHovered: alignRightMouseArea.containsMouse

                        StyledRect {
                            anchors.fill: parent
                            variant: parent.isHovered && noteEditor.cursorSelection.alignment !== Qt.AlignRight ? "surface" : "transparent"
                            radius: Styling.radius(-4)
                            visible: noteEditor.cursorSelection.alignment !== Qt.AlignRight
                        }

                        Text {
                            anchors.centerIn: parent
                            text: Icons.alignRight
                            font.family: Icons.font
                            font.pixelSize: 14
                            color: noteEditor.cursorSelection.alignment === Qt.AlignRight ? Colors.overPrimary : Colors.overSurface
                        }

                        MouseArea {
                            id: alignRightMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                noteEditor.cursorSelection.alignment = Qt.AlignRight;
                                noteEditor.forceActiveFocus();
                            }
                        }

                        StyledToolTip {
                            tooltipText: "Align Right (Alt+Left/Right)"
                            visible: alignRightMouseArea.containsMouse
                        }
                    }

                    // Align Justify
                    Rectangle {
                        id: alignJustifyButton
                        width: 32
                        height: 32
                        radius: Styling.radius(-4)
                        color: noteEditor.cursorSelection.alignment === Qt.AlignJustify ? Styling.srItem("overprimary") : "transparent"

                        property bool isHovered: alignJustifyMouseArea.containsMouse

                        StyledRect {
                            anchors.fill: parent
                            variant: parent.isHovered && noteEditor.cursorSelection.alignment !== Qt.AlignJustify ? "surface" : "transparent"
                            radius: Styling.radius(-4)
                            visible: noteEditor.cursorSelection.alignment !== Qt.AlignJustify
                        }

                        Text {
                            anchors.centerIn: parent
                            text: Icons.alignJustify
                            font.family: Icons.font
                            font.pixelSize: 14
                            color: noteEditor.cursorSelection.alignment === Qt.AlignJustify ? Colors.overPrimary : Colors.overSurface
                        }

                        MouseArea {
                            id: alignJustifyMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                noteEditor.cursorSelection.alignment = Qt.AlignJustify;
                                noteEditor.forceActiveFocus();
                            }
                        }

                        StyledToolTip {
                            tooltipText: "Justify (Alt+Right)"
                            visible: alignJustifyMouseArea.containsMouse
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }

            // Separator below toolbar
            Separator {
                Layout.fillWidth: true
                Layout.preferredHeight: 2
            }

            // WYSIWYG Editor
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"

                Flickable {
                    id: editorFlickable
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: noteEditor.contentHeight + 32
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    TextArea.flickable: TextArea {
                        id: noteEditor
                        text: currentNoteContent
                        textFormat: TextEdit.RichText
                        font.family: Config.theme.font
                        font.pixelSize: Config.theme.fontSize
                        color: Colors.overSurface
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        persistentSelection: true
                        placeholderText: "Start typing..."
                        leftPadding: 8
                        rightPadding: 8
                        topPadding: 8
                        bottomPadding: 8
                        background: Rectangle {
                            color: "transparent"
                        }

                        onTextChanged: {
                            if (currentNoteId && !loadingNote) {
                                editorDirty = true;
                                saveDebounceTimer.restart();
                            }
                        }

                        // Track if cursor moved due to typing or user navigation
                        property int lastCursorPos: 0
                        property bool cursorMovedByTyping: false

                        // Reset pre-format when cursor moves by navigation (not typing)
                        onCursorPositionChanged: {
                            if (applyingFormat)
                                return;

                            // If length changed, cursor moved due to typing - don't reset
                            if (cursorMovedByTyping) {
                                cursorMovedByTyping = false;
                                lastCursorPos = cursorPosition;
                                return;
                            }

                            // Cursor moved by more than 1 position or moved backward = navigation
                            let delta = cursorPosition - lastCursorPos;
                            if (delta < 0 || delta > 1) {
                                resetPreFormat();
                            }
                            lastCursorPos = cursorPosition;
                        }

                        Keys.onEscapePressed: {
                            searchInput.focusInput();
                        }

                        // Formatting shortcuts
                        Keys.onPressed: event => {
                            if (event.modifiers & Qt.ControlModifier) {
                                switch (event.key) {
                                case Qt.Key_B:
                                    toggleBold();
                                    event.accepted = true;
                                    break;
                                case Qt.Key_I:
                                    toggleItalic();
                                    event.accepted = true;
                                    break;
                                case Qt.Key_U:
                                    toggleUnderline();
                                    event.accepted = true;
                                    break;
                                case Qt.Key_D:
                                    toggleStrikeout();
                                    event.accepted = true;
                                    break;
                                }
                            }
                            // Alt+Up/Down to increase/decrease font size
                            // Alt+Left/Right to cycle through alignments
                            if (event.modifiers & Qt.AltModifier) {
                                if (event.key === Qt.Key_Up) {
                                    let currentSize = getCurrentFontSize();
                                    let newSize = Math.min(200, currentSize + 2);
                                    setFontSize(newSize);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down) {
                                    let currentSize = getCurrentFontSize();
                                    let newSize = Math.max(8, currentSize - 2);
                                    setFontSize(newSize);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Left) {
                                    // Cycle alignment: Justify -> Right -> Center -> Left
                                    let current = noteEditor.cursorSelection.alignment;
                                    if (current === Qt.AlignJustify) {
                                        noteEditor.cursorSelection.alignment = Qt.AlignRight;
                                    } else if (current === Qt.AlignRight) {
                                        noteEditor.cursorSelection.alignment = Qt.AlignHCenter;
                                    } else if (current === Qt.AlignHCenter) {
                                        noteEditor.cursorSelection.alignment = Qt.AlignLeft;
                                    }
                                    // Already at Left, do nothing
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Right) {
                                    // Cycle alignment: Left -> Center -> Right -> Justify
                                    let current = noteEditor.cursorSelection.alignment;
                                    if (current === Qt.AlignLeft) {
                                        noteEditor.cursorSelection.alignment = Qt.AlignHCenter;
                                    } else if (current === Qt.AlignHCenter) {
                                        noteEditor.cursorSelection.alignment = Qt.AlignRight;
                                    } else if (current === Qt.AlignRight) {
                                        noteEditor.cursorSelection.alignment = Qt.AlignJustify;
                                    }
                                    // Already at Justify, do nothing
                                    event.accepted = true;
                                }
                            }
                        }

                        // Apply pre-format when inserting text
                        property int lastLength: 0
                        property bool applyingFormat: false
                        onLengthChanged: {
                            // Prevent recursion
                            if (applyingFormat)
                                return;

                            // Mark that cursor will move due to typing
                            if (length !== lastLength) {
                                cursorMovedByTyping = true;
                            }

                            // Detect if text was inserted (not deleted)
                            if (length > lastLength && !hasSelection() && hasActivePreFormat()) {
                                // Apply pre-format to newly typed character
                                let pos = cursorPosition;
                                if (pos > 0) {
                                    applyingFormat = true;
                                    // Select the just-typed character
                                    select(pos - 1, pos);
                                    // Apply explicit format states
                                    if (preFormatBold !== null)
                                        cursorSelection.font.bold = preFormatBold;
                                    if (preFormatItalic !== null)
                                        cursorSelection.font.italic = preFormatItalic;
                                    if (preFormatUnderline !== null)
                                        cursorSelection.font.underline = preFormatUnderline;
                                    if (preFormatStrikeout !== null)
                                        cursorSelection.font.strikeout = preFormatStrikeout;
                                    if (preFormatFontSize !== null)
                                        cursorSelection.font.pixelSize = preFormatFontSize;
                                    // Deselect and move cursor back
                                    cursorPosition = pos;
                                    applyingFormat = false;
                                }
                            }
                            lastLength = length;
                        }
                    }

                    ScrollBar.vertical: ScrollBar {
                        active: true
                    }
                }
            }
        }

        // Right panel: Markdown Editor (split view)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            visible: currentNoteId !== "" && currentNoteIsMarkdown

            // Markdown formatting toolbar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 4

                    // Heading level controls
                    Rectangle {
                        id: headingMinusButton
                        width: 32
                        height: 32
                        radius: Styling.radius(-4)
                        color: "transparent"

                        property bool isHovered: headingMinusMouse.containsMouse

                        StyledRect {
                            anchors.fill: parent
                            variant: parent.isHovered ? "surface" : "transparent"
                            radius: Styling.radius(-4)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: Icons.minus
                            font.family: Icons.font
                            font.pixelSize: 14
                            color: Colors.overSurface
                        }

                        MouseArea {
                            id: headingMinusMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.mdDecreaseHeading()
                        }

                        StyledToolTip {
                            tooltipText: "Decrease heading (Alt+Down)"
                            visible: headingMinusMouse.containsMouse
                        }
                    }

                    Rectangle {
                        width: 40
                        height: 32
                        radius: Styling.radius(-4)
                        color: "transparent"

                        StyledRect {
                            anchors.fill: parent
                            variant: "surface"
                            radius: Styling.radius(-4)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.mdCurrentHeading || "P"
                            font.family: Config.theme.font
                            font.pixelSize: 14
                            font.bold: true
                            color: Colors.overSurface
                        }
                    }

                    Rectangle {
                        id: headingPlusButton
                        width: 32
                        height: 32
                        radius: Styling.radius(-4)
                        color: "transparent"

                        property bool isHovered: headingPlusMouse.containsMouse

                        StyledRect {
                            anchors.fill: parent
                            variant: parent.isHovered ? "surface" : "transparent"
                            radius: Styling.radius(-4)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: Icons.plus
                            font.family: Icons.font
                            font.pixelSize: 14
                            color: Colors.overSurface
                        }

                        MouseArea {
                            id: headingPlusMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.mdIncreaseHeading()
                        }

                        StyledToolTip {
                            tooltipText: "Increase heading (Alt+Up)"
                            visible: headingPlusMouse.containsMouse
                        }
                    }

                    // Separator
                    Rectangle {
                        width: 1
                        height: 24
                        color: Colors.outline
                        opacity: 0.3
                    }

                    // Bold button
                    Rectangle {
                        id: mdBoldButton
                        width: 32
                        height: 32
                        radius: Styling.radius(-4)
                        color: "transparent"

                        property bool isHovered: mdBoldMouse.containsMouse

                        StyledRect {
                            anchors.fill: parent
                            variant: parent.isHovered ? "surface" : "transparent"
                            radius: Styling.radius(-4)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "B"
                            font.family: Config.theme.font
                            font.pixelSize: 14
                            font.bold: true
                            color: Colors.overSurface
                        }

                        MouseArea {
                            id: mdBoldMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.mdToggleBold()
                        }

                        StyledToolTip {
                            tooltipText: "Bold (Ctrl+B)"
                            visible: mdBoldMouse.containsMouse
                        }
                    }

                    // Italic button
                    Rectangle {
                        id: mdItalicButton
                        width: 32
                        height: 32
                        radius: Styling.radius(-4)
                        color: "transparent"

                        property bool isHovered: mdItalicMouse.containsMouse

                        StyledRect {
                            anchors.fill: parent
                            variant: parent.isHovered ? "surface" : "transparent"
                            radius: Styling.radius(-4)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "I"
                            font.family: Config.theme.font
                            font.pixelSize: 14
                            font.italic: true
                            color: Colors.overSurface
                        }

                        MouseArea {
                            id: mdItalicMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.mdToggleItalic()
                        }

                        StyledToolTip {
                            tooltipText: "Italic (Ctrl+I)"
                            visible: mdItalicMouse.containsMouse
                        }
                    }

                    // Underline button
                    Rectangle {
                        id: mdUnderlineButton
                        width: 32
                        height: 32
                        radius: Styling.radius(-4)
                        color: "transparent"

                        property bool isHovered: mdUnderlineMouse.containsMouse

                        StyledRect {
                            anchors.fill: parent
                            variant: parent.isHovered ? "surface" : "transparent"
                            radius: Styling.radius(-4)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "U"
                            font.family: Config.theme.font
                            font.pixelSize: 14
                            font.underline: true
                            color: Colors.overSurface
                        }

                        MouseArea {
                            id: mdUnderlineMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.mdToggleUnderline()
                        }

                        StyledToolTip {
                            tooltipText: "Underline (Ctrl+U)"
                            visible: mdUnderlineMouse.containsMouse
                        }
                    }

                    // Strikethrough button
                    Rectangle {
                        id: mdStrikeButton
                        width: 32
                        height: 32
                        radius: Styling.radius(-4)
                        color: "transparent"

                        property bool isHovered: mdStrikeMouse.containsMouse

                        StyledRect {
                            anchors.fill: parent
                            variant: parent.isHovered ? "surface" : "transparent"
                            radius: Styling.radius(-4)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "S"
                            font.family: Config.theme.font
                            font.pixelSize: 14
                            font.strikeout: true
                            color: Colors.overSurface
                        }

                        MouseArea {
                            id: mdStrikeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.mdToggleStrikethrough()
                        }

                        StyledToolTip {
                            tooltipText: "Strikethrough (Ctrl+D)"
                            visible: mdStrikeMouse.containsMouse
                        }
                    }

                    // Separator
                    Rectangle {
                        width: 1
                        height: 24
                        color: Colors.outline
                        opacity: 0.3
                    }

                    // Code button
                    Rectangle {
                        id: mdCodeButton
                        width: 32
                        height: 32
                        radius: Styling.radius(-4)
                        color: "transparent"

                        property bool isHovered: mdCodeMouse.containsMouse

                        StyledRect {
                            anchors.fill: parent
                            variant: parent.isHovered ? "surface" : "transparent"
                            radius: Styling.radius(-4)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "<>"
                            font.family: "monospace"
                            font.pixelSize: 12
                            color: Colors.overSurface
                        }

                        MouseArea {
                            id: mdCodeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.mdToggleCode()
                        }

                        StyledToolTip {
                            tooltipText: "Inline code (Ctrl+E)"
                            visible: mdCodeMouse.containsMouse
                        }
                    }

                    // Link button
                    Rectangle {
                        id: mdLinkButton
                        width: 32
                        height: 32
                        radius: Styling.radius(-4)
                        color: "transparent"

                        property bool isHovered: mdLinkMouse.containsMouse

                        StyledRect {
                            anchors.fill: parent
                            variant: parent.isHovered ? "surface" : "transparent"
                            radius: Styling.radius(-4)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: Icons.link
                            font.family: Icons.font
                            font.pixelSize: 14
                            color: Colors.overSurface
                        }

                        MouseArea {
                            id: mdLinkMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.mdInsertLink()
                        }

                        StyledToolTip {
                            tooltipText: "Insert link (Ctrl+K)"
                            visible: mdLinkMouse.containsMouse
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }

            // Separator below toolbar
            Separator {
                Layout.fillWidth: true
                Layout.preferredHeight: 2
            }

            // Split view: Editor and Preview
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                // Markdown Editor
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"

                    Flickable {
                        id: mdEditorFlickable
                        anchors.fill: parent
                        contentWidth: width
                        contentHeight: mdEditor.contentHeight + height * 0.5  // Extra bottom margin for scroll
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        // Flag to prevent sync loops
                        property bool syncing: false

                        // Sync editor scroll to preview
                        function syncToPreview() {
                            if (syncing || !mdPreviewFlickable)
                                return;
                            syncing = true;
                            let ratio = contentHeight > height ? contentY / Math.max(1, contentHeight - height) : 0;
                            let targetY = ratio * (mdPreviewFlickable.contentHeight - mdPreviewFlickable.height);
                            if (mdPreviewFlickable.contentHeight > mdPreviewFlickable.height) {
                                mdPreviewFlickable.contentY = Math.max(0, Math.min(targetY, mdPreviewFlickable.contentHeight - mdPreviewFlickable.height));
                            }
                            syncing = false;
                        }

                        onContentYChanged: {
                            syncToPreview();
                        }

                        TextArea.flickable: TextArea {
                            id: mdEditor
                            text: currentNoteContent
                            textFormat: TextEdit.PlainText
                            font.family: Config.theme.monoFont
                            font.pixelSize: Config.theme.monoFontSize
                            font.weight: Font.Medium
                            color: Colors.overSurface
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            placeholderText: "Write markdown here..."
                            leftPadding: 8
                            rightPadding: 8
                            topPadding: 8
                            bottomPadding: 8
                            background: Rectangle {
                                color: "transparent"
                            }

                            onTextChanged: {
                                if (currentNoteId && !loadingNote && currentNoteIsMarkdown) {
                                    editorDirty = true;
                                    saveDebounceTimer.restart();
                                }
                                root.mdUpdateHeadingDisplay();
                                // Sync after text changes with small delay to let layout update
                                mdSyncTimer.restart();
                            }

                            onCursorPositionChanged: {
                                root.mdUpdateHeadingDisplay();
                                // Ensure cursor is visible and sync preview
                                mdSyncTimer.restart();
                            }

                            // Timer to debounce sync calls
                            Timer {
                                id: mdSyncTimer
                                interval: 50
                                repeat: false
                                onTriggered: {
                                    // Make sure cursor is visible in editor
                                    let cursorRect = mdEditor.cursorRectangle;
                                    if (cursorRect.y < mdEditorFlickable.contentY) {
                                        mdEditorFlickable.contentY = Math.max(0, cursorRect.y - 20);
                                    } else if (cursorRect.y + cursorRect.height > mdEditorFlickable.contentY + mdEditorFlickable.height) {
                                        mdEditorFlickable.contentY = Math.min(mdEditorFlickable.contentHeight - mdEditorFlickable.height, cursorRect.y + cursorRect.height - mdEditorFlickable.height + 20);
                                    }
                                    // Sync will happen via onContentYChanged
                                }
                            }

                            Keys.onEscapePressed: {
                                searchInput.focusInput();
                            }

                            // Markdown formatting shortcuts
                            Keys.onPressed: event => {
                                if (event.modifiers & Qt.ControlModifier) {
                                    switch (event.key) {
                                    case Qt.Key_B:
                                        root.mdToggleBold();
                                        event.accepted = true;
                                        break;
                                    case Qt.Key_I:
                                        root.mdToggleItalic();
                                        event.accepted = true;
                                        break;
                                    case Qt.Key_U:
                                        root.mdToggleUnderline();
                                        event.accepted = true;
                                        break;
                                    case Qt.Key_D:
                                        root.mdToggleStrikethrough();
                                        event.accepted = true;
                                        break;
                                    case Qt.Key_E:
                                        root.mdToggleCode();
                                        event.accepted = true;
                                        break;
                                    case Qt.Key_K:
                                        root.mdInsertLink();
                                        event.accepted = true;
                                        break;
                                    }
                                }
                                if (event.modifiers & Qt.AltModifier) {
                                    if (event.key === Qt.Key_Up) {
                                        root.mdIncreaseHeading();
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Down) {
                                        root.mdDecreaseHeading();
                                        event.accepted = true;
                                    }
                                }
                            }
                        }

                        ScrollBar.vertical: ScrollBar {
                            active: true
                        }
                    }
                }

                // Separator
                Separator {
                    Layout.preferredWidth: 2
                    Layout.fillHeight: true
                    vert: true
                }

                // Markdown Preview
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"

                    Flickable {
                        id: mdPreviewFlickable
                        anchors.fill: parent
                        contentWidth: width
                        contentHeight: mdPreviewText.contentHeight + height * 0.5  // Extra bottom margin for scroll
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        // Sync preview scroll to editor (only on manual interaction)
                        onContentYChanged: {
                            if ((mdPreviewFlickable.moving || mdPreviewFlickable.dragging) && !mdEditorFlickable.syncing) {
                                mdEditorFlickable.syncing = true;
                                let ratio = contentHeight > height ? contentY / Math.max(1, contentHeight - height) : 0;
                                let targetY = ratio * (mdEditorFlickable.contentHeight - mdEditorFlickable.height);
                                if (mdEditorFlickable.contentHeight > mdEditorFlickable.height) {
                                    mdEditorFlickable.contentY = Math.max(0, Math.min(targetY, mdEditorFlickable.contentHeight - mdEditorFlickable.height));
                                }
                                mdEditorFlickable.syncing = false;
                            }
                        }

                        TextEdit {
                            id: mdPreviewText
                            width: mdPreviewFlickable.width - 16
                            x: 8
                            y: 8
                            textFormat: TextEdit.MarkdownText
                            text: mdEditor.text
                            font.family: Config.theme.font
                            font.pixelSize: Config.theme.fontSize
                            color: Colors.overSurface
                            wrapMode: TextEdit.Wrap
                            readOnly: true
                            selectByMouse: true
                        }

                        ScrollBar.vertical: ScrollBar {
                            active: true
                        }
                    }
                }
            }
        }

        // Placeholder when no note selected
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            visible: currentNoteId === ""

            Text {
                anchors.centerIn: parent
                text: "Select or create a note"
                font.family: Config.theme.font
                font.pixelSize: Config.theme.fontSize
                color: Colors.outline
            }
        }
    }

    // Loading overlay (outside RowLayout to avoid anchor warning)
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.8)
        visible: loadingNote
        radius: Styling.radius(4)

        Text {
            anchors.centerIn: parent
            text: Icons.spinnerGap
            font.family: Icons.font
            font.pixelSize: 24
            color: Colors.overSurface

            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
                running: loadingNote
            }
        }
    }

    // Root-level key handler for delete/rename mode navigation
    Keys.onPressed: event => {
        if (root.deleteMode) {
            if (event.key === Qt.Key_Left) {
                root.deleteButtonIndex = 0;
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                root.deleteButtonIndex = 1;
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                if (root.deleteButtonIndex === 0) {
                    root.cancelDeleteMode();
                } else {
                    root.confirmDeleteNote();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.cancelDeleteMode();
                event.accepted = true;
            }
        } else if (root.renameMode) {
            if (event.key === Qt.Key_Left) {
                root.renameButtonIndex = 0;
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                root.renameButtonIndex = 1;
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.cancelRenameMode();
                event.accepted = true;
            }
        }
    }
}
