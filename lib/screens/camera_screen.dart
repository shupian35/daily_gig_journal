import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// 全屏中文相机页面
/// 使用 camera 插件实现，UI 完全中文化
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _isInitializing = false;
          _errorMessage = '未检测到相机设备';
        });
        return;
      }

      // 优先使用后置摄像头
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = '相机启动失败: $e';
        });
      }
    }
  }

  Future<void> _capture() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final image = await _controller!.takePicture();
      if (mounted) {
        Navigator.of(context).pop(image.path);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isInitializing
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('正在启动相机...',
                      style: TextStyle(color: Colors.white70, fontSize: 15)),
                ],
              ),
            )
          : _errorMessage != null
              ? _buildErrorView()
              : _buildCameraView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.camera_alt_outlined,
              size: 56, color: Colors.white38),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(null),
            icon: const Icon(Icons.arrow_back),
            label: const Text('返回'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.black,
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    final size = MediaQuery.of(context).size;
    // 预览区域占满屏幕，下方留出操作栏
    final previewHeight = size.height - 140;

    return Column(
      children: [
        // 相机预览
        SizedBox(
          width: size.width,
          height: previewHeight,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: size.width,
                  height: size.width / _controller!.value.aspectRatio,
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          ),
        ),

        // 底部操作栏
        Container(
          height: 140,
          color: Colors.black,
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 取消按钮
                _buildBottomBtn(
                  Icons.close,
                  '取消',
                  () => Navigator.of(context).pop(null),
                ),
                // 拍照按钮
                GestureDetector(
                  onTap: _isCapturing ? null : _capture,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Center(
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                // 翻转镜头按钮
                _buildBottomBtn(
                  Icons.flip_camera_android,
                  '翻转',
                  _switchCamera,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Future<void> _switchCamera() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final cameras = await availableCameras();
    if (cameras.length < 2) return;

    final currentDirection = _controller!.description.lensDirection;
    final newDirection = currentDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    final newCamera = cameras.firstWhere(
      (c) => c.lensDirection == newDirection,
      orElse: () => cameras.first,
    );

    await _controller!.dispose();
    _controller = CameraController(
      newCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();
    setState(() {});
  }
}
