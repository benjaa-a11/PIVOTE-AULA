# Pivote Aula

Plataforma integral de organización universitaria **100% offline, privada, rápida y segura** desarrollada en **Flutter + Riverpod + SQLite (Drift)**.

## Funcionalidades principales

- **Materias y Plan de Carrera**: Organización por cuatrimestre/período, créditos, estado académico (*Cursando*, *Regular*, *Aprobada*, *Libre*, *Recursando*), docentes, aulas y cuaderno de apuntes integrado.
- **Horarios de Cursada**: Grilla semanal (Lunes a Domingo), detección automática de superposiciones, modalidad (*Presencial*, *Virtual*, *Híbrida*, *Práctica / Lab*) y vista en vivo de clases en curso en Inicio.
- **Agenda, Parciales y Entregas**: Calendario mensual interactivo, gestor de tareas/TPs/trámites con prioridades y fechas límite, y desglose reordenable de unidades de estudio por evaluación.
- **Control de Asistencia**: Registro rápido por fecha (*Presente*, *Ausente*, *Justificada*, *Sin clase*) con cálculo automático de porcentaje efectivo de regularidad.
- **Notas, Promedios y Simulador**: Promedio ponderado general y por materia, promedio simple, promedio sin aplazos, reemplazo automático por recuperatorios, gráfico de evolución y calculadora de nota necesaria.
- **Seguridad y Respaldos**: Bloqueo por PIN de 4 dígitos y biometría, instantáneas automáticas locales rotativas (WAL checkpoint) y exportación/importación `.aula` con verificación SHA-256 y cifrado AES-GCM opcional.
- **Diseño Responsivo**: Adaptado a móviles, tablets y escritorio con barra de navegación inferior o barra lateral (`NavigationRail`), modo claro/oscuro y acentos personalizables.

## Requisitos

- Flutter SDK `>= 3.5.0`
- Dart SDK `3.5+`
- Android `minSdk 24`

## Ejecución local

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Compilación Release (Android)

```bash
flutter build apk --release
```
