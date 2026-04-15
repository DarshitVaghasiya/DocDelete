import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:doc_delete/Models/images_model.dart';
import 'package:doc_delete/Widgets/custom_iconbutton.dart';
import 'package:doc_delete/utils/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ImageViewerSheet extends StatefulWidget {
  final String manifestNo;
  final List<PhotoModel> photos;

  const ImageViewerSheet({
    super.key,
    required this.manifestNo,
    required this.photos,
  });

  @override
  State<ImageViewerSheet> createState() => ImageViewerSheetState();
}

class ImageViewerSheetState extends State<ImageViewerSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  int _selectedIndex = -1;

  void _openMap(PhotoModel photo) async {
    if (photo.lat == null || photo.lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.location_off_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text("Location not available for this photo"),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    final url = Uri.parse(
      "https://www.google.com/maps?q=${photo.lat},${photo.lng}",
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Uint8List _decodeImage(String raw) {
    try {
      final cleaned = raw.contains(',') ? raw.split(',').last : raw;
      return base64Decode(cleaned);
    } catch (_) {
      return Uint8List(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImages = widget.photos.isNotEmpty;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFB),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            /// ── Drag Handle ──
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),

            /// ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  /// Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.darkGreen.withOpacity(0.15),
                          AppColors.darkGreen.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.photo_library_rounded,
                      color: AppColors.darkGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Images",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A2E),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              "Manifest #${widget.manifestNo}",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (hasImages) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.darkGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "${widget.photos.length} photos",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.darkGreen,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  /// Close
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppColors.red,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 8),

            /// ── CONTENT ──
            Expanded(child: hasImages ? _buildGrid() : _emptyState()),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    final width = MediaQuery.of(context).size.width;

    // Responsive columns
    final int crossAxisCount = width < 600 ? 2 : 4; // Mobile: 2 | Tablet+: 4

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: widget.photos.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75, // Slightly adjusted for better look
      ),
      itemBuilder: (context, index) {
        final photo = widget.photos[index];
        final imageBytes = _decodeImage(photo.image);
        final isSelected = _selectedIndex == index;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _selectedIndex = isSelected ? -1 : index);
            _openFullScreen(index);
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            setState(() => _selectedIndex = index);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: isSelected
                  ? Border.all(color: AppColors.darkGreen, width: 2.5)
                  : Border.all(color: Colors.transparent, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isSelected ? 0.15 : 0.07),
                  blurRadius: isSelected ? 16 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    /// ─── IMAGE ───
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          imageBytes.isNotEmpty
                              ? Image.memory(imageBytes, fit: BoxFit.cover)
                              : _errorWidget(),

                          /// Dark gradient bottom
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 50,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.5),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),

                          /// Index badge
                          Positioned(
                            top: 7,
                            left: 7,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.45),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Center(
                                child: Text(
                                  "${index + 1}",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          /// Fullscreen icon
                          Positioned(
                            top: 7,
                            right: 7,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Icon(
                                Icons.open_in_full_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    /// ─── LOCATION FOOTER ───
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      color: Colors.white,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: photo.lat != null
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              photo.lat != null
                                  ? Icons.location_on_rounded
                                  : Icons.location_off_rounded,
                              size: 11,
                              color: photo.lat != null
                                  ? Colors.green.shade600
                                  : Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: photo.lat != null
                                ? Text(
                                    "${photo.lat!.toStringAsFixed(3)}, ${photo.lng!.toStringAsFixed(3)}",
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : Text(
                                    "No location",
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                          ),

                          if (photo.lat != null)
                            GestureDetector(
                              onTap: () => _openMap(photo),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF1A73E8,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.map_outlined,
                                      size: 10,
                                      color: Color(0xFF1A73E8),
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      "Map",
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Color(0xFF1A73E8),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openFullScreen(int index) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: _FullScreenViewer(
            photos: widget.photos,
            images: widget.photos.map((p) => _decodeImage(p.image)).toList(),
            initialIndex: index,
            onOpenMap: _openMap,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Widget _errorWidget() {
    return Container(
      color: Colors.grey.shade50,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_rounded,
              size: 32,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 6),
            Text(
              "Unavailable",
              style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.darkGreen.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.image_search_rounded,
              size: 40,
              color: AppColors.darkGreen.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "No Photos Yet",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Photos will appear here\nonce added to the manifest.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// ══════════════════════════════════════════
/// FULL SCREEN VIEWER
/// ══════════════════════════════════════════
class _FullScreenViewer extends StatefulWidget {
  final List<Uint8List> images;
  final List<PhotoModel> photos;
  final int initialIndex;
  final Function(PhotoModel) onOpenMap;

  const _FullScreenViewer({
    required this.images,
    required this.photos,
    required this.initialIndex,
    required this.onOpenMap,
  });

  @override
  State<_FullScreenViewer> createState() => _FullScreenViewerState();
}

class _FullScreenViewerState extends State<_FullScreenViewer>
    with SingleTickerProviderStateMixin {
  late int _current;
  bool _showUI = true;
  late PageController _pageController;
  late AnimationController _uiController;
  late Animation<double> _uiAnim;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _uiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    _uiAnim = CurvedAnimation(parent: _uiController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _uiController.dispose();
    super.dispose();
  }

  void _toggleUI() {
    setState(() => _showUI = !_showUI);
    if (_showUI) {
      _uiController.forward();
    } else {
      _uiController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_current];

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          /// ── IMAGE PAGER ──
          GestureDetector(
            onTap: _toggleUI,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (i) {
                HapticFeedback.selectionClick();
                setState(() => _current = i);
              },
              itemBuilder: (_, index) => InteractiveViewer(
                minScale: 0.8,
                maxScale: 5.0,
                child: Center(
                  child: widget.images[index].isNotEmpty
                      ? Image.memory(widget.images[index], fit: BoxFit.contain)
                      : const Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white38,
                          size: 56,
                        ),
                ),
              ),
            ),
          ),

          /// ── TOP BAR ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _uiAnim,
              child: IgnorePointer(
                ignoring: !_showUI,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 10,
                    left: 16,
                    right: 16,
                    bottom: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Photo ${_current + 1} of ${widget.images.length}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (photo.lat != null)
                            Text(
                              "${photo.lat!.toStringAsFixed(4)}, ${photo.lng!.toStringAsFixed(4)}",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                        ],
                      ),

                      CustomIconButton(
                        icon: Icons.close,
                        textColor: Colors.white,
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
