import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:green_house_app/core/theme/app_colors.dart';
import 'package:green_house_app/core/theme/app_spacing.dart';
import 'package:green_house_app/core/theme/app_text_styles.dart';
import 'package:green_house_app/core/services/api_service.dart';

class SettingsPage extends StatefulWidget {
  final bool isActive;

  const SettingsPage({super.key, this.isActive = true});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic>? _settingsData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive && _settingsData == null && !_isLoading) {
      _fetchSettings();
    }
  }

  Future<void> _fetchSettings() async {
    if (!mounted) return;
    setState(() {
      if (_settingsData == null) _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await ApiService.getSettings();
      if (!mounted) return;
      setState(() {
        _settingsData = data;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _settingsData ??= ApiService.cachedSettings;
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
      if (widget.isActive && _settingsData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat pengaturan: $_errorMessage')),
        );
      }
    }
  }

  Future<void> _showEditProfileDialog() async {
    final nameController = TextEditingController(text: _settingsData?['user_name'] ?? '');
    final roleController = TextEditingController(text: _settingsData?['user_role'] ?? '');
    String currentAvatarUrl = _settingsData?['avatar_url'] ?? '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.spaceLg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Edit Profil',
                      style: AppTextStyles.headlineMd.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spaceLg),
                    
                    // Modern Avatar Picker
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          if (!context.mounted) return;
                          
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: CircularProgressIndicator(color: AppColors.primary),
                            ),
                          );
                          
                          try {
                            final url = await ApiService.uploadAvatar(File(image.path));
                            if (url != null) {
                              setDialogState(() {
                                currentAvatarUrl = url;
                              });
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Gagal mengunggah foto')),
                              );
                            }
                          } finally {
                            if (context.mounted) Navigator.pop(context); // Close loading dialog
                          }
                        }
                      },
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.surfaceContainerHigh,
                            backgroundImage: currentAvatarUrl.isNotEmpty
                                ? NetworkImage(currentAvatarUrl)
                                : null,
                            child: currentAvatarUrl.isEmpty
                                ? const Icon(Icons.person, size: 40, color: AppColors.textSecondary)
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.surface, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: AppSpacing.spaceLg),
                    _buildModernTextField(nameController, 'Nama Lengkap', Icons.person),
                    const SizedBox(height: AppSpacing.spaceMd),
                    _buildModernTextField(roleController, 'Jabatan', Icons.work),
                    const SizedBox(height: AppSpacing.spaceLg),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                          ),
                          child: const Text('Batal'),
                        ),
                        const SizedBox(width: AppSpacing.spaceSm),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            setState(() => _isLoading = true);
                            try {
                              await ApiService.updateSettings({
                                'user_name': nameController.text,
                                'user_role': roleController.text,
                                'avatar_url': currentAvatarUrl,
                              });
                              await _fetchSettings();
                            } catch (e) {
                              setState(() => _isLoading = false);
                            }
                          },
                          child: const Text('Simpan'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModernTextField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_settingsData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.spaceXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.danger),
              const SizedBox(height: AppSpacing.spaceMd),
              Text('Gagal memuat pengaturan.', style: AppTextStyles.headlineSm),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.spaceXs),
                Text(
                  _errorMessage!,
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppSpacing.spaceLg),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: _showServerConfigDialog,
                    icon: const Icon(Icons.dns_rounded, size: 18),
                    label: const Text('Server URL'),
                  ),
                  const SizedBox(width: AppSpacing.spaceSm),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                    ),
                    onPressed: _fetchSettings,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchSettings,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.margin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.spaceLg + 12),
            _buildProfileCard(),
            const SizedBox(height: AppSpacing.spaceLg),
            _buildHardwareCard(),
            const SizedBox(height: AppSpacing.spaceLg),
            _buildAppInfoCard(),
            const SizedBox(height: AppSpacing.spaceLg + 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final avatar = _settingsData?['avatar_url'] ?? '';
    final name = _settingsData?['user_name'] ?? 'User';
    final role = _settingsData?['user_role'] ?? 'Role';

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D47A1), // deep blue
            Color(0xFF1565C0), // blue
            Color(0xFF1B5E20), // green
            Color(0xFF2E7D32), // mid green
          ],
          stops: [0.0, 0.3, 0.65, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(6, 8),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Glowing radial orb – top right
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.cyan.withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Glowing orb – bottom left
          Positioned(
            bottom: -20,
            left: 40,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF69F0AE).withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(AppSpacing.spaceLg),
            child: Column(
              children: [
                Row(
                  children: [
                    // Avatar with colored ring
                    Stack(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const SweepGradient(
                              colors: [
                                Color(0xFF4FC3F7),
                                Color(0xFF69F0AE),
                                Color(0xFFFFB74D),
                                Color(0xFF4FC3F7),
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2.5),
                            child: ClipOval(
                              child: Image.network(
                                avatar,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    size: 36,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFF69F0AE),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF69F0AE).withValues(alpha: 0.6),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.spaceMd),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: AppTextStyles.headlineSm.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified,
                                color: Color(0xFF69F0AE),
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            role,
                            style: AppTextStyles.bodySm.copyWith(
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF69F0AE).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(9999),
                              border: Border.all(
                                color: const Color(0xFF69F0AE).withValues(alpha: 0.5),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '● Sesi Aktif',
                              style: AppTextStyles.labelSm.copyWith(
                                color: const Color(0xFF69F0AE),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      onPressed: _showEditProfileDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Chips row
                Row(
                  children: [
                    _profileChip(Icons.eco, 'Agronomist',
                        const Color(0xFF69F0AE)),
                    const SizedBox(width: 8),
                    _profileChip(Icons.memory, 'ESP32 Node',
                        const Color(0xFF4FC3F7)),
                    const SizedBox(width: 8),
                    _profileChip(Icons.cloud, 'IoT Active',
                        const Color(0xFFFFB74D)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.25),
                          AppColors.primary.withValues(alpha: 0.10),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.memory,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Node Hardware ESP32',
                        style: AppTextStyles.headlineSm.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'ESP32 DevKit V4 — Node 01',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Online',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0x12000000)),
          const SizedBox(height: 14),
          // Specs grid
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _specTile(Icons.wifi, 'Koneksi WiFi',
                        _settingsData?['wifi_signal'] ?? '-58 dBm',
                        'Sangat Bagus', AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _specTile(Icons.system_update, 'Firmware',
                        _settingsData?['firmware_version'] ?? 'v2.4.1-rc',
                        'Terbaru', null),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _specTile(Icons.lan, 'Alamat IP',
                        _settingsData?['ip_address'] ?? '192.168.1.145',
                        'DHCP Tetap', null,
                        isMono: true),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _specTile(Icons.sync_alt, 'Protokol',
                        'MQTT & WS', 'Flask Server Live', null),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _showServerConfigDialog,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.dns_rounded, size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Server API Base URL',
                              style: AppTextStyles.labelSm.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              ApiService.baseUrl,
                              style: AppTextStyles.labelMd.copyWith(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showServerConfigDialog() async {
    final controller = TextEditingController(text: ApiService.baseUrl);
    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ubah Server Base URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan alamat server API (domain hosting atau IP lokal):',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'https://api-greenhouse.andanafarm.web.id/api',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            onPressed: () {
              final newUrl = controller.text.trim();
              Navigator.pop(dialogCtx);
              if (newUrl.isNotEmpty) {
                ApiService.setBaseUrl(newUrl);
                _fetchSettings();
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Base URL diatur: ${ApiService.baseUrl}')),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Widget _specTile(
    IconData icon,
    String label,
    String value,
    String subValue,
    Color? subColor, {
    bool isMono = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: AppColors.primary),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTextStyles.labelMd.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w700,
              fontFamily: isMono ? 'monospace' : null,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subValue,
            style: AppTextStyles.bodySm.copyWith(
              color: subColor ?? AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfoCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informasi Aplikasi & Sensor',
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  Text(
                    'Detail versi dan spesifikasi sensor',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spaceMd + 8),
          _buildInfoRow(Icons.android, 'Versi Aplikasi', 'v1.0.0 (Build 42)'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: AppColors.outlineVariant),
          ),
          _buildInfoRow(Icons.device_thermostat, 'Sensor Udara', 'SHT30 / DHT22'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: AppColors.outlineVariant),
          ),
          _buildInfoRow(Icons.water_drop, 'Sensor Air', 'Analog pH & EC Meter'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: AppColors.outlineVariant),
          ),
          _buildInfoRow(Icons.grass, 'Sensor Tanah', 'RS485 Modbus NPK'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.labelMd.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }



}
