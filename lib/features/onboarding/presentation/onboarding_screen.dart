import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_radius.dart';
import '../../../core/design_system/app_scroll_physics.dart';
import '../../../core/design_system/app_spacing.dart';
import '../../../core/design_system/app_typography.dart';
import '../../../core/design_system/components/app_button.dart';
import '../../../core/design_system/components/app_card.dart';
import '../../../core/design_system/components/app_chip.dart';
import '../../../core/design_system/components/app_text_field.dart';
import '../../../core/design_system/components/aula_logo.dart';
import '../../../core/design_system/responsive.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/services/backup_service.dart';
import '../../profile/presentation/academic_unit_autocomplete_field.dart';
import '../../profile/presentation/avatar_view.dart';
import '../../profile/presentation/profile_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isRestoringBackup = false;
  List<File> _localBackups = const [];

  final _nameController = TextEditingController();
  final _careerController = TextEditingController();
  final _universityController = TextEditingController();
  final _yearController = TextEditingController(text: '1er año');
  final _periodController = TextEditingController(
    text: '1er Cuatrimestre ${DateTime.now().year}',
  );
  final _studentIdController = TextEditingController();
  final _emailController = TextEditingController();

  String? _photoPath;
  String _themeMode = 'system';
  int _accentColorValue = AppColors.defaultAccentValue;
  String _gradeScale = '1-10';
  double _passingGrade = 4.0;
  bool _remindersEnabled = true;

  String? _nameError;
  String? _careerError;
  String? _universityError;

  @override
  void initState() {
    super.initState();
    _refreshLocalBackups();
  }

  Future<void> _refreshLocalBackups() async {
    try {
      final backups = await BackupService(ref.read(appDatabaseProvider))
          .listLocalBackups();
      if (mounted) setState(() => _localBackups = backups);
    } catch (_) {
      if (mounted) setState(() => _localBackups = const []);
    }
  }

  String _localBackupDate(File file) {
    final date = file.lastModifiedSync();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} · ${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  Future<String?> _askBackupPassword() async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Respaldo protegido'),
        content: AppTextField(
          controller: controller,
          label: 'Contraseña del respaldo',
          hint: 'Ingresá la contraseña usada al exportar',
          obscureText: true,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Desbloquear'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (password == null) return null;
    if (password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Ingresá la contraseña para abrir este respaldo.'),
          ),
        );
      }
      return null;
    }
    return password;
  }

  Future<void> _restoreBackupFile() async {
    if (_isRestoringBackup) return;

    File? stagedFile;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['aula', 'zip'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;

      final selectedFile = result.files.single;
      final selectedPath = selectedFile.path;
      late final String backupPath;

      if (selectedPath != null &&
          selectedPath.isNotEmpty &&
          await File(selectedPath).exists()) {
        backupPath = selectedPath;
      } else {
        final bytes = selectedFile.bytes;
        if (bytes == null || bytes.isEmpty) {
          throw Exception(
            'No se pudo leer el archivo seleccionado. Probá elegirlo desde Descargas o Archivos.',
          );
        }

        final tempDirectory = await getTemporaryDirectory();
        stagedFile = File(
          '${tempDirectory.path}${Platform.pathSeparator}'
          'aula_import_${DateTime.now().microsecondsSinceEpoch}.aula',
        );
        await stagedFile.writeAsBytes(bytes, flush: true);
        backupPath = stagedFile.path;
      }

      if (!mounted) return;
      setState(() => _isRestoringBackup = true);

      final service = BackupService(ref.read(appDatabaseProvider));
      final encrypted = await service.backupRequiresPassword(backupPath);
      final password = encrypted ? await _askBackupPassword() : null;
      if (encrypted && password == null) return;

      await service.restoreBackup(backupPath, password: password);
      await _finishRestoreFlow();
    } catch (error) {
      if (mounted) {
        final message = error.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo restaurar el respaldo: $message')),
        );
      }
    } finally {
      if (stagedFile != null) {
        try {
          if (await stagedFile.exists()) await stagedFile.delete();
        } catch (_) {}
      }
      if (mounted && _isRestoringBackup) {
        setState(() => _isRestoringBackup = false);
      }
    }
  }

  Future<void> _restoreLocalSnapshot() async {
    if (_isRestoringBackup || _localBackups.isEmpty) return;
    final selected = await showDialog<File>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Copias guardadas en este dispositivo'),
        content: SizedBox(
          width: 360,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _localBackups.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final file = _localBackups[index];
                final size = file.lengthSync();
                final sizeLabel = size > 1024 * 1024
                    ? '${(size / (1024 * 1024)).toStringAsFixed(1)} MB'
                    : '${(size / 1024).toStringAsFixed(0)} KB';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history_rounded),
                  title: Text(_localBackupDate(file)),
                  subtitle: Text('$sizeLabel · Instantánea local'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(ctx).pop(file),
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;

    setState(() => _isRestoringBackup = true);
    try {
      await BackupService(ref.read(appDatabaseProvider))
          .restoreLocalBackup(selected.path);
      await _finishRestoreFlow();
    } catch (error) {
      if (mounted) {
        final message = error.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo recuperar la copia local: $message'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoringBackup = false);
    }
  }

  Future<void> _finishRestoreFlow() async {
    final profile = await ref.read(appDatabaseProvider).getProfile();
    if (!mounted) return;
    if (profile != null) {
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tus materias y notas se recuperaron. Completá tu perfil para finalizar.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
      await _refreshLocalBackups();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _careerController.dispose();
    _universityController.dispose();
    _yearController.dispose();
    _periodController.dispose();
    _studentIdController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 1) {
      bool hasError = false;
      setState(() {
        _nameError = _nameController.text.trim().isEmpty
            ? 'Ingresá tu nombre y apellido'
            : null;
        _careerError = _careerController.text.trim().isEmpty
            ? 'Ingresá tu carrera'
            : null;
        _universityError = _universityController.text.trim().isEmpty
            ? 'Ingresá tu universidad o facultad'
            : null;
        hasError = _nameError != null ||
            _careerError != null ||
            _universityError != null;
      });
      if (hasError) return;
    }

    if (_currentPage < 3) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final controller = ref.read(profileControllerProvider.notifier);
    final path = await controller.pickAndSaveImage(source);
    if (path != null && mounted) {
      setState(() => _photoPath = path);
    }
  }

  Future<void> _finishOnboarding() async {
    final controller = ref.read(profileControllerProvider.notifier);
    await controller.saveProfile(
      fullName: _nameController.text,
      career: _careerController.text,
      university: _universityController.text,
      currentYear: _yearController.text,
      currentPeriod: _periodController.text,
      studentId: _studentIdController.text,
      email: _emailController.text,
      photoPath: _photoPath,
      themeMode: _themeMode,
      accentColorValue: _accentColorValue,
      gradeScale: _gradeScale,
      passingGrade: _passingGrade,
      remindersEnabled: _remindersEnabled,
    );

    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeAccent = Color(_accentColorValue);

    return Scaffold(
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 560,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: _previousPage,
                      )
                    else
                      const SizedBox(width: 44),
                    const Spacer(),
                    Row(
                      children: List.generate(4, (index) {
                        final isActive = index == _currentPage;
                        final isPast = index < _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: isActive ? 24 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: isActive || isPast
                                ? activeAccent
                                : AppColors.border(context),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const Spacer(),
                    if (_currentPage == 2)
                      TextButton(
                        onPressed: _nextPage,
                        child: const Text(AppStrings.skipBtn),
                      )
                    else
                      const SizedBox(width: 44),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  children: [
                    _buildWelcomePage(context, activeAccent),
                    _buildDataPage(context),
                    _buildPhotoPage(context, theme),
                    _buildPreferencesPage(context, activeAccent),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppButton(
                      label: _currentPage == 3
                          ? AppStrings.finishBtn
                          : AppStrings.continueBtn,
                      trailingIcon: _currentPage == 3
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                      onPressed: _isRestoringBackup ? null : _nextPage,
                      isExpanded: true,
                      height: 52,
                    ),
                    if (_currentPage == 0) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed:
                                _isRestoringBackup ? null : _restoreBackupFile,
                            icon: _isRestoringBackup
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.folder_open_rounded,
                                    size: 18,
                                  ),
                            label: Text(
                              _isRestoringBackup
                                  ? 'Restaurando…'
                                  : 'Restaurar respaldo .aula',
                            ),
                          ),
                          if (_localBackups.isNotEmpty)
                            TextButton.icon(
                              onPressed: _isRestoringBackup
                                  ? null
                                  : _restoreLocalSnapshot,
                              icon: const Icon(Icons.history_rounded, size: 18),
                              label: Text(
                                'Copia local (${_localBackups.length})',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomePage(BuildContext context, Color activeAccent) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      physics: appScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          AulaLogoMark(
            size: 88,
            accentColor: activeAccent,
            showGlow: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: ShapeDecoration(
              color: activeAccent.withValues(alpha: 0.12),
              shape: AppRadius.continuousSm(),
            ),
            child: Text(
              'PIVOTE AULA',
              style: AppTypography.eyebrow.copyWith(
                color: activeAccent,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Todo tu recorrido universitario, bajo control.',
            textAlign: TextAlign.center,
            style: AppTypography.display.copyWith(
              color: AppColors.textPrimary(context),
              fontSize: 28,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Registrá materias, horarios de cursada, parciales, entregas, asistencia, temas y promedios en segundos. Rápido, seguro y 100% offline.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const _FeatureRow(
            icon: Icons.schedule_rounded,
            title: 'Cursada, Agenda y Entregas',
            subtitle: 'Horarios semanales, calendario de parciales y tareas.',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _FeatureRow(
            icon: Icons.insights_rounded,
            title: 'Promedios Reales y Asistencia',
            subtitle:
                'Ponderaciones, recuperatorios automáticos y control de faltas.',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _FeatureRow(
            icon: Icons.shield_outlined,
            title: 'Privada, Rápida y Respaldada',
            subtitle:
                'Base SQLite local con respaldos cifrados AES-GCM y bloqueo PIN.',
          ),
        ],
      ),
    );
  }

  Widget _buildDataPage(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      physics: appScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.studentDataTitle,
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.studentDataSubtitle,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            controller: _nameController,
            label: AppStrings.fullName,
            hint: AppStrings.fullNameHint,
            errorText: _nameError,
            textCapitalization: TextCapitalization.words,
            prefixIcon: const Icon(Icons.person_outline_rounded),
            onChanged: (val) {
              if (_nameError != null && val.trim().isNotEmpty) {
                setState(() => _nameError = null);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _careerController,
            label: AppStrings.career,
            hint: AppStrings.careerHint,
            errorText: _careerError,
            textCapitalization: TextCapitalization.sentences,
            prefixIcon: const Icon(Icons.school_outlined),
            onChanged: (val) {
              if (_careerError != null && val.trim().isNotEmpty) {
                setState(() => _careerError = null);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AcademicUnitAutocompleteField(
            controller: _universityController,
            label: AppStrings.university,
            hint: 'Buscá tu universidad, facultad o instituto',
            errorText: _universityError,
            onChanged: (value) {
              if (_universityError != null && value.trim().isNotEmpty) {
                setState(() => _universityError = null);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _yearController,
                  label: AppStrings.currentYear,
                  hint: AppStrings.currentYearHint,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppTextField(
                  controller: _periodController,
                  label: AppStrings.currentPeriod,
                  hint: AppStrings.currentPeriodHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _studentIdController,
            label: AppStrings.studentId,
            hint: AppStrings.studentIdHint,
            prefixIcon: const Icon(Icons.badge_outlined),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _emailController,
            label: AppStrings.email,
            hint: AppStrings.emailHint,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildPhotoPage(BuildContext context, ThemeData theme) {
    final displayName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Estudiante';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AvatarView(
              photoPath: _photoPath,
              name: displayName,
              size: 112,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              AppStrings.profilePhoto,
              style: AppTypography.titleLarge.copyWith(
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Opcional: elegí una imagen o usá tus iniciales generadas automáticamente.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                AppButton(
                  label: AppStrings.choosePhoto,
                  icon: Icons.photo_library_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                ),
                AppButton(
                  label: AppStrings.takePhoto,
                  icon: Icons.camera_alt_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _pickPhoto(ImageSource.camera),
                ),
              ],
            ),
            if (_photoPath != null) ...[
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => setState(() => _photoPath = null),
                child: Text(
                  AppStrings.removePhoto,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesPage(BuildContext context, Color activeAccent) {
    final isHundred = _gradeScale == '0-100';
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      physics: appScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.preferencesTitle,
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.preferencesSubtitle,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(AppStrings.theme, style: AppTypography.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppChip(
                label: 'Automático',
                isSelected: _themeMode == 'system',
                activeColor: activeAccent,
                icon: const Icon(Icons.brightness_auto_rounded, size: 15),
                onTap: () => setState(() => _themeMode = 'system'),
              ),
              AppChip(
                label: 'Claro',
                isSelected: _themeMode == 'light',
                activeColor: activeAccent,
                icon: const Icon(Icons.light_mode_outlined, size: 15),
                onTap: () => setState(() => _themeMode = 'light'),
              ),
              AppChip(
                label: 'Oscuro',
                isSelected: _themeMode == 'dark',
                activeColor: activeAccent,
                icon: const Icon(Icons.dark_mode_outlined, size: 15),
                onTap: () => setState(() => _themeMode = 'dark'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(AppStrings.accentColor, style: AppTypography.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: AppColors.accentOptions.map((c) {
              final isSelected = c.toARGB32() == _accentColorValue;
              return GestureDetector(
                onTap: () => setState(() => _accentColorValue = c.toARGB32()),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.textPrimary(context)
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(AppStrings.gradeScale, style: AppTypography.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppChip(
                label: 'Escala 1 a 10',
                isSelected: _gradeScale == '1-10',
                activeColor: activeAccent,
                onTap: () => setState(() {
                  _gradeScale = '1-10';
                  _passingGrade = 4.0;
                }),
              ),
              AppChip(
                label: 'Escala 0 a 100',
                isSelected: _gradeScale == '0-100',
                activeColor: activeAccent,
                onTap: () => setState(() {
                  _gradeScale = '0-100';
                  _passingGrade = 60.0;
                }),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(AppStrings.passingGrade,
                  style: AppTypography.titleSmall),
              Text(
                isHundred
                    ? _passingGrade.toStringAsFixed(0)
                    : _passingGrade.toStringAsFixed(1),
                style: AppTypography.titleMedium.copyWith(
                  color: activeAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Slider(
            value: _passingGrade.clamp(isHundred ? 40 : 1, isHundred ? 80 : 7),
            min: isHundred ? 40 : 1,
            max: isHundred ? 80 : 7,
            divisions: isHundred ? 8 : 12,
            activeColor: activeAccent,
            onChanged: (val) => setState(() => _passingGrade = val),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _remindersEnabled,
            title: const Text(
              AppStrings.enableNotifications,
              style: AppTypography.titleSmall,
            ),
            subtitle: Text(
              'Aviso automático 24 hs antes y la mañana de cada examen',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary(context),
              ),
            ),
            onChanged: (val) => setState(() => _remindersEnabled = val),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: ShapeDecoration(
              color: primary.withValues(alpha: 0.12),
              shape: AppRadius.continuousSm(),
            ),
            child: Icon(icon, color: primary, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.textPrimary(context),
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
