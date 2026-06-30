import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Shows an image that supports pinch/zoom and tap-to-fullscreen.
/// Provide either [url] (network) or [file] (local). [url] takes priority.
class ZoomableImage extends StatelessWidget {
  final String? url;
  final File? file;
  final String heroTag;
  final double? aspectRatio;

  const ZoomableImage({
    super.key,
    this.url,
    this.file,
    required this.heroTag,
    this.aspectRatio,
  }) : assert(url != null || file != null,
            'ZoomableImage: provide url or file');

  @override
  Widget build(BuildContext context) {
    final inner = GestureDetector(
      onTap: () => _openFullscreen(context),
      child: Hero(
        tag: heroTag,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: _imageWidget(),
          ),
        ),
      ),
    );

    return Stack(
      children: [
        aspectRatio != null
            ? AspectRatio(aspectRatio: aspectRatio!, child: inner)
            : inner,
        Positioned(
          bottom: 10,
          right: 10,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.zoom_in, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text('Tap to zoom',
                    style: TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _imageWidget() {
    if (url != null && url!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url!,
        fit: BoxFit.contain,
        placeholder: (_, __) => Container(
          color: AppColors.surface,
          child: const Center(
              child: CircularProgressIndicator(color: AppColors.accent)),
        ),
        errorWidget: (_, __, error) {
          if (kDebugMode) debugPrint('ZoomableImage error: $error');
          return _errorPlaceholder();
        },
      );
    }
    if (file != null) {
      return Image.file(
        file!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _errorPlaceholder(),
      );
    }
    return _errorPlaceholder();
  }

  Widget _errorPlaceholder() {
    return Container(
      color: AppColors.surface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_outlined,
                color: AppColors.textSecondary, size: 32),
            const SizedBox(height: 8),
            Text('Image unavailable',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullScreenImageViewer(
          url: url,
          file: file,
          heroTag: heroTag,
        ),
      ),
    );
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final String? url;
  final File? file;
  final String heroTag;

  const _FullScreenImageViewer({
    required this.heroTag,
    this.url,
    this.file,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 8,
            child: url != null && url!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: url!,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const CircularProgressIndicator(
                        color: Colors.white),
                    errorWidget: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white,
                        size: 48),
                  )
                : file != null
                    ? Image.file(file!, fit: BoxFit.contain)
                    : const Icon(Icons.broken_image_outlined,
                        color: Colors.white, size: 48),
          ),
        ),
      ),
    );
  }
}
