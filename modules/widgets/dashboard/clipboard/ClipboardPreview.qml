import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.config
import qs.modules.services
import "clipboard_utils.js" as ClipboardUtils

// Right-hand preview panel of the clipboard tab; state comes from `tab`.
Item {
    id: previewPanel

    property var tab: null
    property var currentItem: tab ? tab.currentSelectedItem : null
    Layout.fillWidth: true
    Layout.fillHeight: true

        // Content when item is selected
        Item {
            anchors.fill: parent
            visible: previewPanel.currentItem

            // Preview area
            Item {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: separator.top
                anchors.bottomMargin: 8

                // Preview para imagen estática
                Image {
                    mipmap: true
                    id: previewImage
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit
                    visible: previewPanel.currentItem && (previewPanel.currentItem.isImage || isImageFile) && !isGifImage
                    source: {
                        if (previewPanel.currentItem) {
                            if (previewPanel.currentItem.isImage && !isGifImage) {
                                ClipboardService.revision;
                                return ClipboardService.getImageData(previewPanel.currentItem.id, previewPanel.currentItem.hash);
                            } else if (isImageFile && !isGifImage) {
                                var content = tab.safeCurrentContent;
                                var filePath = tab.getFilePathFromUri(content);
                                return filePath ? "file://" + filePath : "";
                            }
                        }
                        return "";
                    }
                    clip: true
                    cache: false
                    asynchronous: true

                    property bool isImageFile: {
                        if (!previewPanel.currentItem || !previewPanel.currentItem.isFile)
                            return false;
                        var content = tab.safeCurrentContent;
                        var filePath = tab.getFilePathFromUri(content);
                        return tab.isImageFile(filePath);
                    }

                    property bool isGifImage: {
                        if (!previewPanel.currentItem)
                            return false;
                        // Check direct image mime type
                        if (previewPanel.currentItem.mime === "image/gif")
                            return true;
                        // Check file extension for text/uri-list
                        if (previewPanel.currentItem.isFile) {
                            var content = tab.safeCurrentContent;
                            var filePath = tab.getFilePathFromUri(content);
                            if (filePath) {
                                var ext = filePath.split('.').pop().toLowerCase();
                                return ext === "gif";
                            }
                        }
                        return false;
                    }
                }

                // Preview para GIF animado
                AnimatedImage {
                    id: previewGif
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit
                    visible: previewPanel.currentItem && (previewPanel.currentItem.isImage || isImageFile) && isGifImage
                    source: {
                        if (previewPanel.currentItem && isGifImage) {
                            if (previewPanel.currentItem.isImage) {
                                ClipboardService.revision;
                                return ClipboardService.getImageData(previewPanel.currentItem.id, previewPanel.currentItem.hash);
                            } else if (isImageFile) {
                                var content = tab.safeCurrentContent;
                                var filePath = tab.getFilePathFromUri(content);
                                return filePath ? "file://" + filePath : "";
                            }
                        }
                        return "";
                    }
                    clip: true
                    cache: false
                    asynchronous: true
                    playing: true

                    property bool isImageFile: {
                        if (!previewPanel.currentItem || !previewPanel.currentItem.isFile)
                            return false;
                        var content = tab.safeCurrentContent;
                        var filePath = tab.getFilePathFromUri(content);
                        return tab.isImageFile(filePath);
                    }

                    property bool isGifImage: {
                        if (!previewPanel.currentItem)
                            return false;
                        // Check direct image mime type
                        if (previewPanel.currentItem.mime === "image/gif")
                            return true;
                        // Check file extension for text/uri-list
                        if (previewPanel.currentItem.isFile) {
                            var content = tab.safeCurrentContent;
                            var filePath = tab.getFilePathFromUri(content);
                            if (filePath) {
                                var ext = filePath.split('.').pop().toLowerCase();
                                return ext === "gif";
                            }
                        }
                        return false;
                    }
                }

                // Placeholder cuando la imagen no está lista
                Rectangle {
                    anchors.centerIn: parent
                    width: 120
                    height: 120
                    color: Colors.surfaceBright
                    radius: Styling.radius(4)
                    visible: {
                        if (!previewPanel.currentItem)
                            return false;
                        var isImg = previewPanel.currentItem.isImage || previewImage.isImageFile || previewGif.isImageFile;
                        if (!isImg)
                            return false;

                        if (previewImage.visible) {
                            return previewImage.status !== Image.Ready;
                        } else if (previewGif.visible) {
                            return previewGif.status !== AnimatedImage.Ready;
                        }
                        return false;
                    }

                    Text {
                        anchors.centerIn: parent
                        text: Icons.image
                        textFormat: Text.RichText
                        font.family: Icons.font
                        font.pixelSize: 48
                        color: Styling.srItem("overprimary")
                    }
                }

                // Preview para texto con scroll
                Flickable {
                    anchors.fill: parent
                    visible: previewPanel.currentItem && !previewPanel.currentItem.isImage && !previewPanel.currentItem.isFile
                    clip: true
                    contentWidth: width
                    contentHeight: textPreviewColumn.height
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: textPreviewColumn
                        width: parent.width
                        spacing: 12

                        // Link embed preview (Discord-style)
                        Rectangle {
                            width: parent.width
                            height: {
                                // For videos (YouTube), use a larger layout
                                if (tab.linkPreviewData && tab.linkPreviewData.type === 'video' && tab.linkPreviewData.image) {
                                    return videoEmbedContent.height + 24;
                                }
                                return linkEmbedContent.height + 24;
                            }
                            visible: tab.linkPreviewData && !tab.linkPreviewData.error && (tab.linkPreviewData.title || tab.linkPreviewData.description || tab.linkPreviewData.image)
                            color: linkPreviewMouseArea.containsMouse ? Colors.surfaceBright : Colors.surface

                            // Rounded corners only on the right side
                            topLeftRadius: 0
                            topRightRadius: Config.roundness > 0 ? Config.roundness + 4 : 0
                            bottomLeftRadius: 0
                            bottomRightRadius: Config.roundness > 0 ? Config.roundness + 4 : 0

                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration / 2
                                    easing.type: Easing.OutQuart
                                }
                            }

                            MouseArea {
                                id: linkPreviewMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    if (tab.safeCurrentContent) {
                                        Qt.openUrlExternally(tab.safeCurrentContent.trim());
                                    }
                                }
                            }

                            // Left accent bar
                            Rectangle {
                                x: 0
                                y: 0
                                width: 4
                                height: parent.height
                                color: Styling.srItem("overprimary")

                                // Rounded corners only on the left side
                                topLeftRadius: Config.roundness > 0 ? Config.roundness + 4 : 0
                                topRightRadius: 0
                                bottomLeftRadius: Config.roundness > 0 ? Config.roundness + 4 : 0
                                bottomRightRadius: 0
                            }

                            // Video embed layout (YouTube, etc.)
                            Column {
                                id: videoEmbedContent
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 12
                                anchors.leftMargin: 16
                                spacing: 10
                                visible: tab.linkPreviewData && tab.linkPreviewData.type === 'video'

                                // Site name with favicon
                                Row {
                                    width: parent.width
                                    spacing: 8
                                    visible: tab.linkPreviewData && tab.linkPreviewData.site_name

                                    Item {
                                        width: 16
                                        height: 16
                                        visible: videoFaviconPrimary.status === Image.Ready || videoFaviconFallback.status === Image.Ready

                                        property bool triedFallback: false

                                        Image {
                                            mipmap: true
                                            id: videoFaviconPrimary
                                            anchors.fill: parent
                                            sourceSize.width: 40
                                            sourceSize.height: 40
                                            source: tab.linkPreviewData && tab.linkPreviewData.favicon ? tab.getUsableFavicon(tab.linkPreviewData.favicon) : ""
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            cache: true
                                            visible: status === Image.Ready

                                            onStatusChanged: {
                                                if (status === Image.Error && !parent.triedFallback) {
                                                    parent.triedFallback = true;
                                                }
                                            }
                                        }

                                        Image {
                                            mipmap: true
                                            id: videoFaviconFallback
                                            anchors.fill: parent
                                            sourceSize.width: 40
                                            sourceSize.height: 40
                                            source: parent.triedFallback && tab.safeCurrentContent ? tab.getUsableFaviconFallback(tab.safeCurrentContent) : ""
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            cache: true
                                            visible: parent.triedFallback && status === Image.Ready && videoFaviconPrimary.status !== Image.Ready
                                        }
                                    }

                                    Text {
                                        text: tab.linkPreviewData ? tab.linkPreviewData.site_name : ""
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-2)
                                        font.weight: Font.Medium
                                        color: Colors.outline
                                        elide: Text.ElideRight
                                        width: parent.width - 24
                                    }
                                }

                                // Video thumbnail with play overlay
                                ClippingRectangle {
                                    id: videoThumbnailContainer
                                    width: parent.width
                                    height: width * 9 / 16  // 16:9 aspect ratio
                                    color: Colors.surfaceBright
                                    radius: Styling.radius(-4)
                                    visible: tab.linkPreviewData && tab.linkPreviewData.image

                                    Image {
                                        mipmap: true
                                        id: videoThumbnail
                                        anchors.fill: parent
                                        source: tab.linkPreviewData && tab.linkPreviewData.image ? tab.linkPreviewData.image : ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        smooth: true

                                        // Dark overlay
                                        Rectangle {
                                            anchors.fill: parent
                                            color: "#40000000"
                                            radius: videoThumbnailContainer.radius
                                        }

                                        // Play button overlay
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 60
                                            height: 60
                                            radius: 30
                                            color: Styling.srItem("overprimary")
                                            opacity: 0.9

                                            Text {
                                                anchors.centerIn: parent
                                                text: Icons.play
                                                font.family: Icons.font
                                                font.pixelSize: 28
                                                color: Colors.overPrimary
                                                textFormat: Text.RichText
                                            }
                                        }

                                        // Loading indicator
                                        Rectangle {
                                            id: imageLoadingRect
                                            anchors.fill: parent
                                            color: Colors.surfaceBright
                                            radius: videoThumbnailContainer.radius
                                            visible: parent.status === Image.Loading

                                            Text {
                                                anchors.centerIn: parent
                                                text: Icons.spinnerGap
                                                font.family: Icons.font
                                                font.pixelSize: 32
                                                color: Styling.srItem("overprimary")
                                                textFormat: Text.RichText

                                                RotationAnimator on rotation {
                                                    from: 0
                                                    to: 360
                                                    duration: 1000
                                                    loops: Animation.Infinite
                                                    running: imageLoadingRect.visible
                                                }
                                            }
                                        }
                                    }
                                }

                                // Title
                                Text {
                                    width: parent.width
                                    text: tab.linkPreviewData && tab.linkPreviewData.title ? tab.linkPreviewData.title : ""
                                    font.family: Config.theme.font
                                    font.pixelSize: Config.theme.fontSize + 1
                                    font.weight: Font.Bold
                                    color: Colors.overBackground
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    visible: text.length > 0
                                }

                                // Author/Description
                                Text {
                                    width: parent.width
                                    text: tab.linkPreviewData && tab.linkPreviewData.description ? tab.linkPreviewData.description : ""
                                    font.family: Config.theme.font
                                    font.pixelSize: Config.theme.fontSize
                                    color: Colors.outline
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    visible: text.length > 0
                                }
                            }

                            // Regular link embed layout
                            Row {
                                id: linkEmbedContent
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 12
                                anchors.leftMargin: 16
                                spacing: 12
                                visible: !tab.linkPreviewData || tab.linkPreviewData.type !== 'video'

                                // Text content column
                                Column {
                                    width: tab.linkPreviewData && tab.linkPreviewData.image ? parent.width - 100 - parent.spacing : parent.width
                                    spacing: 6

                                    // Site name with favicon
                                    Row {
                                        width: parent.width
                                        spacing: 8
                                        visible: tab.linkPreviewData && tab.linkPreviewData.site_name

                                        Item {
                                            width: 16
                                            height: 16
                                            visible: linkFaviconPrimary.status === Image.Ready || linkFaviconFallback.status === Image.Ready

                                            property bool triedFallback: false

                                            Image {
                                                mipmap: true
                                                id: linkFaviconPrimary
                                                anchors.fill: parent
                                                sourceSize.width: 40
                                                sourceSize.height: 40
                                                source: tab.linkPreviewData && tab.linkPreviewData.favicon ? tab.getUsableFavicon(tab.linkPreviewData.favicon) : ""
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                                cache: true
                                                visible: status === Image.Ready

                                                onStatusChanged: {
                                                    if (status === Image.Error && !parent.triedFallback) {
                                                        parent.triedFallback = true;
                                                    }
                                                }
                                            }

                                            Image {
                                                mipmap: true
                                                id: linkFaviconFallback
                                                anchors.fill: parent
                                                sourceSize.width: 40
                                                sourceSize.height: 40
                                                source: parent.triedFallback && tab.safeCurrentContent ? tab.getUsableFaviconFallback(tab.safeCurrentContent) : ""
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                                cache: true
                                                visible: parent.triedFallback && status === Image.Ready && linkFaviconPrimary.status !== Image.Ready
                                            }
                                        }

                                        Text {
                                            text: tab.linkPreviewData ? tab.linkPreviewData.site_name : ""
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-2)
                                            font.weight: Font.Medium
                                            color: Colors.outline
                                            elide: Text.ElideRight
                                            width: parent.width - 24
                                        }
                                    }

                                    // Title
                                    Text {
                                        width: parent.width
                                        text: tab.linkPreviewData && tab.linkPreviewData.title ? tab.linkPreviewData.title : ""
                                        font.family: Config.theme.font
                                        font.pixelSize: Config.theme.fontSize + 1
                                        font.weight: Font.Bold
                                        color: Colors.overBackground
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                        visible: text.length > 0
                                    }

                                    // Description
                                    Text {
                                        width: parent.width
                                        text: tab.linkPreviewData && tab.linkPreviewData.description ? tab.linkPreviewData.description : ""
                                        font.family: Config.theme.font
                                        font.pixelSize: Config.theme.fontSize
                                        color: Colors.outline
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                        visible: text.length > 0
                                    }
                                }

                                // Preview image (thumbnail)
                                Rectangle {
                                    id: linkThumbnailContainer
                                    width: 100
                                    height: 100
                                    color: Colors.surfaceBright
                                    radius: Styling.radius(-4)
                                    visible: tab.linkPreviewData && tab.linkPreviewData.image
                                    anchors.verticalCenter: parent.verticalCenter

                                    Image {
                                        mipmap: true
                                        anchors.fill: parent
                                        source: tab.linkPreviewData && tab.linkPreviewData.image ? tab.linkPreviewData.image : ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        smooth: true

                                        Rectangle {
                                            anchors.fill: parent
                                            color: Colors.surfaceBright
                                            radius: linkThumbnailContainer.radius
                                            visible: parent.status === Image.Loading

                                            Text {
                                                anchors.centerIn: parent
                                                text: Icons.spinnerGap
                                                font.family: Icons.font
                                                font.pixelSize: 24
                                                color: Styling.srItem("overprimary")
                                                textFormat: Text.RichText
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Loading indicator for link preview
                        Rectangle {
                            id: linkPreviewLoadingRect
                            width: parent.width
                            height: 60
                            visible: tab.loadingLinkPreview && previewPanel.currentItem && ClipboardUtils.isUrl(tab.safeCurrentContent)
                            color: Colors.surface
                            radius: Styling.radius(4)

                            Row {
                                anchors.centerIn: parent
                                spacing: 12

                                Text {
                                    text: Icons.spinnerGap
                                    font.family: Icons.font
                                    font.pixelSize: 20
                                    color: Styling.srItem("overprimary")
                                    textFormat: Text.RichText

                                    RotationAnimator on rotation {
                                        from: 0
                                        to: 360
                                        duration: 1000
                                        loops: Animation.Infinite
                                        running: linkPreviewLoadingRect.visible
                                    }
                                }

                                Text {
                                    text: I18n.t("clipboard.loading_preview")
                                    font.family: Config.theme.font
                                    font.pixelSize: Config.theme.fontSize
                                    color: Colors.outline
                                }
                            }
                        }

                        // URL preview with favicon (fallback when no embed available)
                        Item {
                            width: parent.width
                            height: urlPreview.visible ? 60 : 0
                            visible: previewPanel.currentItem && ClipboardUtils.isUrl(tab.safeCurrentContent) && !tab.loadingLinkPreview && (!tab.linkPreviewData || (!tab.linkPreviewData.title && !tab.linkPreviewData.description && !tab.linkPreviewData.image))

                            Rectangle {
                                id: urlPreview
                                anchors.centerIn: parent
                                width: parent.width
                                height: 60
                                color: urlPreviewMouseArea.containsMouse ? Colors.surfaceBright : Colors.surface
                                radius: Styling.radius(4)

                                Behavior on color {
                                    enabled: Config.animDuration > 0
                                    ColorAnimation {
                                        duration: Config.animDuration / 2
                                        easing.type: Easing.OutQuart
                                    }
                                }

                                MouseArea {
                                    id: urlPreviewMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        if (previewPanel.currentItem) {
                                            tab.openItem(previewPanel.currentItem.id);
                                        }
                                    }
                                }

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 12

                                    // Favicon or fallback icon
                                    Rectangle {
                                        width: 36
                                        height: 36
                                        color: Colors.surfaceBright
                                        radius: Styling.radius(-4)

                                        Image {
                                            mipmap: true
                                            id: previewFavicon
                                            anchors.centerIn: parent
                                            width: 24
                                            height: 24
                                            visible: previewPanel.currentItem !== null && status === Image.Ready
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            cache: true

                                            property bool triedFallback: false
                                            property string primarySource: {
                                                if (!previewPanel.currentItem)
                                                    return "";
                                                // Use Google service (PNG) as primary to avoid ICO decode errors
                                                return ClipboardUtils.getFaviconFallbackUrl(tab.safeCurrentContent);
                                            }

                                            source: primarySource

                                            onPrimarySourceChanged: {
                                                triedFallback = false;
                                                source = primarySource;
                                            }

                                            onStatusChanged: {
                                                if (status === Image.Error) {
                                                    if (!triedFallback) {
                                                        triedFallback = true;
                                                        var content = tab.safeCurrentContent;
                                                        // Fallback to direct .ico if Google fails
                                                        source = ClipboardUtils.getFaviconUrl(content);
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: !previewFavicon.visible
                                            text: Icons.globe
                                            font.family: Icons.font
                                            font.pixelSize: 20
                                            color: Styling.srItem("overprimary")
                                            textFormat: Text.RichText
                                        }
                                    }

                                    Column {
                                        width: parent.width - 48 - parent.spacing
                                        height: parent.height
                                        spacing: 4

                                        Text {
                                            text: I18n.t("clipboard.link")
                                            font.family: Config.theme.font
                                            font.pixelSize: Config.theme.fontSize - 1
                                            font.weight: Font.Medium
                                            color: Colors.outline
                                        }

                                        Text {
                                            text: {
                                                if (!previewPanel.currentItem)
                                                    return "";
                                                var url = tab.safeCurrentContent;
                                                try {
                                                    var urlObj = new URL(url.trim());
                                                    return urlObj.hostname;
                                                } catch (e) {
                                                    return url.substring(0, 40) + (url.length > 40 ? "..." : "");
                                                }
                                            }
                                            font.family: Config.theme.font
                                            font.pixelSize: Config.theme.fontSize
                                            font.weight: Font.Bold
                                            color: Colors.overBackground
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            id: previewText
                            text: tab.safeCurrentContent
                            font.family: Config.theme.font
                            font.pixelSize: Config.theme.fontSize
                            color: Colors.overBackground
                            wrapMode: Text.Wrap
                            width: parent.width
                            textFormat: Text.PlainText
                        }
                    }

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }
                }

                // Preview para archivos (text/uri-list) - solo no-imágenes
                Item {
                    anchors.fill: parent
                    visible: previewPanel.currentItem && previewPanel.currentItem.isFile && !isImage

                    property string filePath: {
                        if (!previewPanel.currentItem)
                            return "";
                        var content = tab.safeCurrentContent;
                        return tab.getFilePathFromUri(content);
                    }

                    property bool isImage: tab.isImageFile(filePath)

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (previewPanel.currentItem) {
                                tab.openItem(previewPanel.currentItem.id);
                            }
                        }
                    }

                    // Preview genérico para archivos no-imagen
                    Column {
                        anchors.centerIn: parent
                        spacing: 16

                        Rectangle {
                            width: 120
                            height: 120
                            color: Colors.surfaceBright
                            radius: Styling.radius(4)
                            anchors.horizontalCenter: parent.horizontalCenter

                            Text {
                                anchors.centerIn: parent
                                text: Icons.file
                                textFormat: Text.RichText
                                font.family: Icons.font
                                font.pixelSize: 48
                                color: Styling.srItem("overprimary")
                            }
                        }

                        Column {
                            width: previewPanel.width - 16
                            spacing: 8
                            anchors.horizontalCenter: parent.horizontalCenter

                            Text {
                                text: {
                                    if (!previewPanel.currentItem)
                                        return "";
                                    var content = tab.safeCurrentContent;
                                    if (content.startsWith("file://")) {
                                        var filePath = content.substring(7).trim();
                                        var fileName = filePath.split('/').pop();
                                        // Decode URL encoding (e.g., %20 -> space)
                                        return decodeURIComponent(fileName);
                                    }
                                    return content;
                                }
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize + 2
                                font.weight: Font.Bold
                                color: Colors.overBackground
                                horizontalAlignment: Text.AlignHCenter
                                width: parent.width
                                wrapMode: Text.Wrap
                            }

                            Text {
                                text: {
                                    if (!previewPanel.currentItem)
                                        return "";
                                    var content = tab.safeCurrentContent;
                                    if (content.startsWith("file://")) {
                                        var filePath = content.substring(7).trim();
                                        var parts = filePath.split('/');
                                        parts.pop(); // Remove filename
                                        // Decode each part of the path
                                        var decodedParts = parts.map(function (part) {
                                            return decodeURIComponent(part);
                                        });
                                        return decodedParts.join('/');
                                    }
                                    return "";
                                }
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize - 1
                                color: Colors.outline
                                horizontalAlignment: Text.AlignHCenter
                                width: parent.width
                                wrapMode: Text.Wrap
                                elide: Text.ElideMiddle
                            }
                        }
                    }
                }
            }

            // Separator
            Separator {
                id: separator
                anchors.bottom: metadataSection.top
                anchors.bottomMargin: 8
                anchors.left: parent.left
                anchors.right: parent.right
                height: 2
                vert: false
            }

            // Metadata section
            Item {
                id: metadataSection
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 80

                Row {
                    anchors.fill: parent
                    spacing: 8

                    Column {
                        width: {
                            // Always reserve space for buttons if there's an item
                            return parent.width - (previewPanel.currentItem ? 36 + 8 : 0);
                        }
                        height: parent.height
                        spacing: 4

                        // Row 1: MIME and Size
                        Row {
                            width: parent.width
                            spacing: 16

                            Column {
                                width: (parent.width - parent.spacing) / 2
                                spacing: 2

                                Text {
                                    text: I18n.t("clipboard.mime_type")
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    font.weight: Font.Medium
                                    color: Colors.outline
                                }

                                Text {
                                    text: previewPanel.currentItem ? previewPanel.currentItem.mime : ""
                                    font.family: Config.theme.font
                                    font.pixelSize: Config.theme.fontSize
                                    font.weight: Font.Normal
                                    color: Colors.overBackground
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                            }

                            Column {
                                width: (parent.width - parent.spacing) / 2
                                spacing: 2

                                Text {
                                    text: I18n.t("clipboard.size")
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    font.weight: Font.Medium
                                    color: Colors.outline
                                }

                                Text {
                                    text: {
                                        if (!previewPanel.currentItem)
                                            return "";
                                        var bytes = previewPanel.currentItem.size || 0;
                                        if (bytes < 1024)
                                            return bytes + " B";
                                        if (bytes < 1024 * 1024)
                                            return (bytes / 1024).toFixed(1) + " KB";
                                        return (bytes / (1024 * 1024)).toFixed(1) + " MB";
                                    }
                                    font.family: Config.theme.font
                                    font.pixelSize: Config.theme.fontSize
                                    font.weight: Font.Normal
                                    color: Colors.overBackground
                                }
                            }
                        }

                        // Row 2: Date and Checksum
                        Row {
                            width: parent.width
                            spacing: 16

                            Column {
                                width: (parent.width - parent.spacing) / 2
                                spacing: 2

                                Text {
                                    text: I18n.t("clipboard.date")
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    font.weight: Font.Medium
                                    color: Colors.outline
                                }

                                Text {
                                    text: {
                                        if (!previewPanel.currentItem || !previewPanel.currentItem.createdAt)
                                            return I18n.t("player.unknown");
                                        var date = new Date(previewPanel.currentItem.createdAt);
                                        var monthKeys = [
                                            "calendar.month.january", "calendar.month.february",
                                            "calendar.month.march", "calendar.month.april",
                                            "calendar.month.may", "calendar.month.june",
                                            "calendar.month.july", "calendar.month.august",
                                            "calendar.month.september", "calendar.month.october",
                                            "calendar.month.november", "calendar.month.december"
                                        ];
                                        var h = date.getHours();
                                        var m = String(date.getMinutes()).padStart(2, "0");
                                        var s = String(date.getSeconds()).padStart(2, "0");
                                        var ap = h >= 12 ? "PM" : "AM";
                                        var h12 = h % 12 || 12;
                                        return I18n.t(monthKeys[date.getMonth()]) + " " + date.getDate() + ", " + date.getFullYear() + " " + h12 + ":" + m + ":" + s + " " + ap;
                                    }
                                    font.family: Config.theme.font
                                    font.pixelSize: Config.theme.fontSize
                                    font.weight: Font.Normal
                                    color: Colors.overBackground
                                }
                            }

                            Column {
                                width: (parent.width - parent.spacing) / 2
                                spacing: 2

                                Text {
                                    text: I18n.t("clipboard.checksum")
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    font.weight: Font.Medium
                                    color: Colors.outline
                                }

                                Text {
                                    text: {
                                        if (!previewPanel.currentItem || !previewPanel.currentItem.hash)
                                            return "N/A";
                                        var hash = previewPanel.currentItem.hash;
                                        // Show first 8 and last 8 characters
                                        if (hash.length > 16) {
                                            return hash.substring(0, 8) + "..." + hash.substring(hash.length - 8);
                                        }
                                        return hash;
                                    }
                                    font.family: Config.theme.font
                                    font.pixelSize: Config.theme.fontSize
                                    font.weight: Font.Normal
                                    color: Colors.overBackground
                                    elide: Text.ElideMiddle
                                    width: parent.width
                                }
                            }
                        }
                    }

                    // Action buttons column (Open and Drag)
                    Column {
                        width: 36
                        height: parent.height
                        spacing: 4
                        visible: previewPanel.currentItem !== null

                        // Open button (for files, images, and URLs)
                        StyledRect {
                            width: height
                            height: 36
                            variant: metadataOpenButtonMouseArea.containsMouse ? "focus" : "common"
                            color: metadataOpenButtonMouseArea.containsMouse ? Colors.surfaceBright : Colors.surface
                            radius: Styling.radius(0)
                            visible: {
                                if (!previewPanel.currentItem)
                                    return false;
                                var item = previewPanel.currentItem;
                                return item.isFile || item.isImage || ClipboardUtils.isUrl(tab.safeCurrentContent);
                            }

                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration / 2
                                    easing.type: Easing.OutQuart
                                }
                            }

                            MouseArea {
                                id: metadataOpenButtonMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    if (previewPanel.currentItem) {
                                        tab.openItem(previewPanel.currentItem.id);
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: Icons.popOpen
                                font.family: Icons.font
                                font.pixelSize: 20
                                color: metadataOpenButtonMouseArea.containsMouse ? Styling.srItem("overprimary") : Colors.overBackground
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

                        // Drag button
                        StyledRect {
                            id: dragButton
                            width: height
                            height: 36
                            variant: metadataDragArea.containsMouse ? "focus" : "common"
                            color: metadataDragArea.containsMouse ? Colors.surfaceBright : Colors.surface
                            radius: Styling.radius(0)

                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration / 2
                                    easing.type: Easing.OutQuart
                                }
                            }

                            // Invisible drag target
                            Item {
                                id: dragTarget

                                // Drag properties on the invisible item
                                Drag.active: metadataDragArea.drag.active
                                Drag.dragType: Drag.Automatic
                                Drag.supportedActions: Qt.CopyAction
                                Drag.mimeData: {
                                    ClipboardService.revision;
                                    if (!previewPanel.currentItem)
                                        return {};

                                    var item = previewPanel.currentItem;
                                    var content = tab.safeCurrentContent.trim();

                                    if (item.isFile) {
                                        // File: send as URI list
                                        return {
                                            "text/uri-list": content
                                        };
                                    } else if (item.isImage && ClipboardService.getImagePath(item.id, item.hash)) {
                                        // Image from clipboard: send as file URI
                                        return {
                                            "text/uri-list": "file://" + ClipboardService.getImagePath(item.id, item.hash)
                                        };
                                    } else {
                                        // Text: send as plain text
                                        return {
                                            "text/plain": content
                                        };
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: Icons.handGrab
                                font.family: Icons.font
                                font.pixelSize: 20
                                color: metadataDragArea.containsMouse ? Styling.srItem("overprimary") : Colors.overBackground
                                textFormat: Text.RichText

                                Behavior on color {
                                    enabled: Config.animDuration > 0
                                    ColorAnimation {
                                        duration: Config.animDuration / 2
                                        easing.type: Easing.OutQuart
                                    }
                                }
                            }

                            MouseArea {
                                id: metadataDragArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.OpenHandCursor
                                drag.target: dragTarget
                            }
                        }
                    }
                }
            }
        }

        // Placeholder cuando no hay nada seleccionado
        Column {
            anchors.centerIn: parent
            spacing: 16
            visible: !previewPanel.currentItem

            Text {
                text: Icons.cactus
                font.family: Icons.font
                font.pixelSize: 48
                color: Colors.surfaceBright
                anchors.horizontalCenter: parent.horizontalCenter
                textFormat: Text.RichText
            }
        }
}
