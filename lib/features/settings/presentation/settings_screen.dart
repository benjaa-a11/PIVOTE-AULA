import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_scroll_physics.dart';
import '../../../core/design_system/app_spacing.dart';
import '../../../core/design_system/app_typography.dart';
import '../../../core/design_system/components/app_card.dart';
import '../../../core/design_system/components/app_chip.dart';
import '../../../core/design_system/components/app_text_field.dart';
import '../../../core/design_system/components/aula_logo.dart';
import '../../../core/design_system/responsive.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/security_service.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/avatar_view.dart';
import '../../profile/presentation/edit_profile_sheet.dart';
import '../../profile/presentation/profile_controller.dart';
import '../../subjects/presentation/subject_form_preferences.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _lockEnabled = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSecurityStatus();
  }

  Future<void> _loadSecurityStatus() async {
    final lock = await SecurityService.instance.isLockEnabled();
    final bio = await SecurityService.instance.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _lockEnabled = lock;
        _biometricEnabled = bio;
      });
    }
  }

  Future<void> _setupPinDialog() async {
    final controller = TextEditingController();
    String? pinError;

    final savedPin = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Configurar PIN de seguridad'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ingresá exactamente 4 dígitos numéricos para proteger el acceso a tus datos.',
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: controller,
                keyboardType: TextInputType.number,
                obscureText: true,
                autofocus: true,
                hint: 'Ej. 2580',
                errorText: pinError,
                onChanged: (_) {
                  if (pinError != null) {
                    setDialogState(() => pinError = null);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (!RegExp(r'^\d{4}$').hasMatch(text)) {
                  setDialogState(
                    () => pinError = 'El PIN debe tener exactamente 4 números',
                  );
                  return;
                }
                Navigator.pop(ctx, text);
              },
              child: const Text('Activar PIN'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();

    if (savedPin != null) {
      await SecurityService.instance.setPin(savedPin);
      await _loadSecurityStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bloqueo por PIN activado.')),
        );
      }
    }
  }

  Future<void> _exportBackup() async {
    final passwordController = TextEditingController();
    bool usePassword = false;
    String? pwError;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Exportar respaldo completo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Se exportará un paquete .aula con perfil, materias, horarios, exámenes, tareas, asistencia, apuntes y notas.',
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Cifrar con contraseña (AES-GCM)',
                  style: AppTypography.titleSmall,
                ),
                value: usePassword,
                onChanged: (val) => setDialogState(() {
                  usePassword = val;
                  pwError = null;
                }),
              ),
              if (usePassword) ...[
                const SizedBox(height: AppSpacing.xs),
                AppTextField(
                  controller: passwordController,
                  obscureText: true,
                  hint: 'Mínimo 4 caracteres',
                  errorText: pwError,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (usePassword && passwordController.text.trim().length < 4) {
                  setDialogState(
                    () => pwError = 'Usá una contraseña de al menos 4 caracteres',
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Exportar'),
            ),
          ],
        ),
      ),
    );

    final password = passwordController.text;
    passwordController.dispose();

    if (proceed == true) {
      try {
        final db = ref.read(appDatabaseProvider);
        final backupService = BackupService(db);
        final path = await backupService.exportBackup(
          password: usePassword ? password : null,
        );
        await backupService.shareBackupFile(path);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al exportar: $e')),
          );
        }
      }
    }
  }

  Future<void> _importBackup() async {
    File? stagedFile;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['aula', 'zip'],
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;

      final selected = result.files.single;
      late final String backupPath;

      if (selected.path != null &&
          selected.path!.isNotEmpty &&
          await File(selected.path!).exists()) {
        backupPath = selected.path!;
      } else if (selected.bytes != null && selected.bytes!.isNotEmpty) {
        final temp = await getTemporaryDirectory();
        stagedFile = File(
          '${temp.path}${Platform.pathSeparator}restore_${DateTime.now().microsecondsSinceEpoch}.aula',
        );
        await stagedFile.writeAsBytes(selected.bytes!, flush: true);
        backupPath = stagedFile.path;
      } else {
        throw Exception('No se pudo acceder al archivo seleccionado.');
      }

      final service = BackupService(ref.read(appDatabaseProvider));
      final requiresPassword = await service.backupRequiresPassword(backupPath);
      if (!mounted) return;

      final passwordController = TextEditingController();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restaurar respaldo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Se reemplazarán los datos actuales con los contenidos en el respaldo verificado.',
              ),
              if (requiresPassword) ...[
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: passwordController,
                  label: 'Contraseña del respaldo',
                  obscureText: true,
                  autofocus: true,
                  hint: 'Ingresá la contraseña de cifrado',
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restaurar ahora'),
            ),
          ],
        ),
      );
      final pw = passwordController.text;
      passwordController.dispose();

      if (confirm == true) {
        await service.restoreBackup(
          backupPath,
          password: requiresPassword ? pw : null,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Respaldo restaurado con éxito.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al restaurar: $msg')),
        );
      }
    } finally {
      if (stagedFile != null) {
        try {
          if (await stagedFile.exists()) await stagedFile.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _restoreLocalSnapshotDialog() async {
    final service = BackupService(ref.read(appDatabaseProvider));
    final snapshots = await service.listLocalBackups();
    if (!mounted) return;

    if (snapshots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aún no hay instantáneas automáticas en este dispositivo.'),
        ),
      );
      return;
    }

    final chosen = await showDialog<File>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Instantáneas automáticas'),
        content: SizedBox(
          width: 360,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: snapshots.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, idx) {
              final f = snapshots[idx];
              final d = f.lastModifiedSync();
              String two(int n) => n.toString().padLeft(2, '0');
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history_rounded),
                title: Text(
                  '${two(d.day)}/${two(d.month)}/${d.year} · ${two(d.hour)}:${two(d.minute)}',
                ),
                subtitle: const Text('Copia automática verificada'),
                onTap: () => Navigator.pop(ctx, f),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );

    if (chosen != null && mounted) {
      try {
        await service.restoreLocalBackup(chosen.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Instantánea local restaurada.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo restaurar: $e')),
          );
        }
      }
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar absolutamente todo?'),
        content: const Text(
          'Esta acción eliminará perfil, materias, horarios, exámenes, tareas, asistencias y notas de este dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Borrar todo',
              style: TextStyle(
                color: AppColors.errFg(ctx),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(appDatabaseProvider);
      await db.clearAllData();
      await SecurityService.instance.clearSecurity();
      if (mounted) context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileStreamProvider).value;
    final subjectFormPreferences = ref.watch(subjectFormPreferencesProvider);
    final subjectFormPreferencesController =
        ref.read(subjectFormPreferencesProvider.notifier);

    Widget subjectPreferenceTile({
      required String title,
      required String subtitle,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) {
      return SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(title, style: AppTypography.titleSmall),
        subtitle: Text(
          subtitle,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary(context),
          ),
        ),
        value: value,
        onChanged: onChanged,
      );
    }

    final isHundred = profile?.gradeScale == '0-100';

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settings, style: AppTypography.titleLarge),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          context.pageHorizontalPadding,
          AppSpacing.lg,
          context.pageHorizontalPadding,
          88,
        ),
        physics: appScrollPhysics(),
        children: [
          ResponsiveContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (profile != null) ...[
                  AppCard(
                    onTap: () => EditProfileSheet.show(context, profile),
                    child: Row(
                      children: [
                        AvatarView(
                          photoPath: profile.photoPath,
                          name: profile.fullName,
                          size: 58,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.fullName,
                                style: AppTypography.titleMedium,
                              ),
                              Text(
                                '${profile.career} · ${profile.university}',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                [
                                  profile.currentYear,
                                  profile.currentPeriod,
                                  if (profile.studentId != null)
                                    'Legajo ${profile.studentId}',
                                ].join(' · '),
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textTertiary(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_outlined, size: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],

                // Apariencia
                const Text('Apariencia', style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(AppStrings.theme, style: AppTypography.titleSmall),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          AppChip(
                            label: 'Sistema',
                            isSelected: profile?.themeMode == 'system',
                            onTap: () => ref
                                .read(profileControllerProvider.notifier)
                                .updateAppearance(themeMode: 'system'),
                          ),
                          AppChip(
                            label: 'Claro',
                            isSelected: profile?.themeMode == 'light',
                            onTap: () => ref
                                .read(profileControllerProvider.notifier)
                                .updateAppearance(themeMode: 'light'),
                          ),
                          AppChip(
                            label: 'Oscuro',
                            isSelected: profile?.themeMode == 'dark',
                            onTap: () => ref
                                .read(profileControllerProvider.notifier)
                                .updateAppearance(themeMode: 'dark'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const Text(
                        AppStrings.accentColor,
                        style: AppTypography.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: AppColors.accentOptions.map((c) {
                          final isSelected =
                              c.toARGB32() == profile?.accentColorValue;
                          return GestureDetector(
                            onTap: () => ref
                                .read(profileControllerProvider.notifier)
                                .updateAppearance(
                                  accentColorValue: c.toARGB32(),
                                ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.textPrimary(context)
                                      : Colors.transparent,
                                  width: 2.4,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 17,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Reducir animaciones',
                          style: AppTypography.titleSmall,
                        ),
                        subtitle: Text(
                          'Transiciones instantáneas sin movimiento elástico',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        value: profile?.reduceMotion ?? false,
                        onChanged: (val) => ref
                            .read(profileControllerProvider.notifier)
                            .updateAppearance(reduceMotion: val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Reglas Académicas
                if (profile != null) ...[
                  const Text(
                    'Reglas académicas y alertas',
                    style: AppTypography.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          AppStrings.gradeScale,
                          style: AppTypography.titleSmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            AppChip(
                              label: 'Escala 1 a 10',
                              isSelected: !isHundred,
                              onTap: () => ref
                                  .read(profileControllerProvider.notifier)
                                  .updateAcademicSettings(
                                    gradeScale: '1-10',
                                    passingGrade: 4.0,
                                  ),
                            ),
                            AppChip(
                              label: 'Escala 0 a 100',
                              isSelected: isHundred,
                              onTap: () => ref
                                  .read(profileControllerProvider.notifier)
                                  .updateAcademicSettings(
                                    gradeScale: '0-100',
                                    passingGrade: 60.0,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Nota mínima general',
                              style: AppTypography.titleSmall,
                            ),
                            Text(
                              isHundred
                                  ? profile.passingGrade.toStringAsFixed(0)
                                  : profile.passingGrade.toStringAsFixed(1),
                              style: AppTypography.titleMedium.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: profile.passingGrade
                              .clamp(isHundred ? 40 : 1, isHundred ? 80 : 7),
                          min: isHundred ? 40 : 1,
                          max: isHundred ? 80 : 7,
                          divisions: isHundred ? 8 : 12,
                          onChanged: (val) => ref
                              .read(profileControllerProvider.notifier)
                              .updateAcademicSettings(passingGrade: val),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Recordatorios de exámenes',
                            style: AppTypography.titleSmall,
                          ),
                          subtitle: Text(
                            'Notificaciones locales 24 hs antes y la mañana del examen',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                          value: profile.remindersEnabled,
                          onChanged: (val) => ref
                              .read(profileControllerProvider.notifier)
                              .updateAcademicSettings(remindersEnabled: val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],

                // Formulario de materias
                const Text(
                  'Formulario de materias',
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      subjectPreferenceTile(
                        title: 'Selector de color',
                        subtitle: 'Mostrar paleta de colores por materia',
                        value: subjectFormPreferences.showColorPicker,
                        onChanged: (v) => subjectFormPreferencesController
                            .update(showColorPicker: v),
                      ),
                      const Divider(height: 1),
                      subjectPreferenceTile(
                        title: 'Selector de ícono',
                        subtitle: 'Mostrar íconos académicos representativos',
                        value: subjectFormPreferences.showIconPicker,
                        onChanged: (v) => subjectFormPreferencesController
                            .update(showIconPicker: v),
                      ),
                      const Divider(height: 1),
                      subjectPreferenceTile(
                        title: 'Código y créditos',
                        subtitle: 'Identificador y carga de créditos',
                        value: subjectFormPreferences.showCodeField,
                        onChanged: (v) =>
                            subjectFormPreferencesController.update(
                          showCodeField: v,
                          showCreditsField: v,
                        ),
                      ),
                      const Divider(height: 1),
                      subjectPreferenceTile(
                        title: 'Docente y aula',
                        subtitle: 'Datos de cátedra y comisión',
                        value: subjectFormPreferences.showProfessorField,
                        onChanged: (v) =>
                            subjectFormPreferencesController.update(
                          showProfessorField: v,
                          showClassroomField: v,
                        ),
                      ),
                      const Divider(height: 1),
                      subjectPreferenceTile(
                        title: 'Nota mínima y observaciones',
                        subtitle: 'Umbral particular de aprobación y notas',
                        value: subjectFormPreferences.showPassingGrade,
                        onChanged: (v) =>
                            subjectFormPreferencesController.update(
                          showPassingGrade: v,
                          showNotesField: v,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Seguridad
                const Text(
                  'Seguridad y privacidad',
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Bloqueo con PIN',
                          style: AppTypography.titleSmall,
                        ),
                        subtitle: Text(
                          'Protege tus datos al abrir o volver a la app',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        value: _lockEnabled,
                        onChanged: (val) async {
                          if (val) {
                            await _setupPinDialog();
                          } else {
                            await SecurityService.instance.clearSecurity();
                            await _loadSecurityStatus();
                          }
                        },
                      ),
                      if (_lockEnabled) ...[
                        const Divider(height: 1),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Desbloqueo biométrico',
                            style: AppTypography.titleSmall,
                          ),
                          subtitle: Text(
                            'Huella dactilar o reconocimiento facial',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                          value: _biometricEnabled,
                          onChanged: (val) async {
                            await SecurityService.instance
                                .setBiometricEnabled(val);
                            await _loadSecurityStatus();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Respaldos
                const Text(
                  'Respaldos y recuperación',
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.ios_share_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: const Text(
                          'Exportar archivo .aula',
                          style: AppTypography.titleSmall,
                        ),
                        subtitle: const Text(
                          'Respaldo completo con verificación SHA-256 y cifrado opcional',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _exportBackup,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.download_rounded,
                          color: AppColors.okFg(context),
                        ),
                        title: const Text(
                          'Importar respaldo .aula',
                          style: AppTypography.titleSmall,
                        ),
                        subtitle: const Text(
                          'Restaurá tus datos desde un archivo guardado',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _importBackup,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.history_rounded,
                          color: AppColors.warnFg(context),
                        ),
                        title: const Text(
                          'Instantáneas locales automáticas',
                          style: AppTypography.titleSmall,
                        ),
                        subtitle: const Text(
                          'Recuperá cualquiera de las últimas 5 copias internas',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _restoreLocalSnapshotDialog,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Zona peligrosa
                Text(
                  'Restablecimiento',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.errFg(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  border: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.45),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.delete_forever_rounded,
                      color: AppColors.errFg(context),
                    ),
                    title: Text(
                      'Borrar todos los datos',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.errFg(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: const Text(
                      'Elimina permanentemente toda la información de este dispositivo',
                    ),
                    onTap: _clearAllData,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                const Center(
                  child: AulaBrandLockup(markSize: 30, showTagline: true),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'v2.0.0 · 100% Offline, Segura y Sin Publicidad',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary(context),
                    ),
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
