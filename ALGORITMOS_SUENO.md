# Análisis de algoritmos de sueño (Oura, Apple, SleepWatch)

Marco de referencia para comparar enfoques públicos de detección y puntuación del sueño frente a VitrikFit (HealthKit + reglas en app). No sustituye documentación legal de terceros.

---

## Límite metodológico (importante)

Ninguna de estas apps publica el **código** ni **fórmulas cerradas** con pesos exactos para el score agregado. Lo que sí existe es: documentación de marketing, centros de ayuda, papers o PDFs técnicos de Apple, y papers científicos o blogs de Oura. Todo lo demás son **estimaciones** o divulgación parcial.

---

## Oura

**Detección de fases (staging)**

- Combina señales del anillo: **movimiento, FC, HRV, temperatura relativa de piel, frecuencia respiratoria** (según posts oficiales).
- El modelo es de **machine learning** entrenado con datasets grandes; Oura reporta validación frente a **PSG** (por ejemplo ~79% acuerdo en clasificación de 4 etapas en comunicados recientes). Hay publicación en revista **Sensors** citada por Oura para el algoritmo 2.0.
- La puntuación depende de qué tan bien se etiquetan las fases; es un pipeline **propio de hardware + ML**, no es “solo HealthKit”.

**Sleep Score (0–100)**

- Oura lo expone como **siete contribuidores**: Total sleep, Efficiency, Restfulness, REM, Deep, Latency, Timing.
- Ayuda y blog conectan umbrales cualitativos con **recomendaciones tipo AASM** (por ejemplo eficiencia ~85% óptima en adultos; REM “óptimo” en torno a **≥90 min** en documentación de marketing; deep con referencias por edad).
- **Los pesos entre contribuyentes no son públicos**; el score 85+ se describe como “óptimo” y 100 como poco frecuente a propósito.

**Idea clave**: Oura **controla sensores + modelo** y separa explícitamente **calidad del sueño** (score) de **readiness** en otro score.

---

## Apple (Salud / Apple Watch)

**Qué documenta Apple con detalle (PDF técnico)**

- White paper: [Estimating Sleep Stages from Apple Watch](https://www.apple.com/health/pdf/Estimating_Sleep_Stages_from_Apple_Watch_Oct_2025.pdf) (actualizaciones hasta 2025).
- **Entrada principal al algoritmo de fases**: **acelerómetro de 3 ejes** en el Apple Watch.
- Clasifica **cada 30 s** (epoch) en: **Awake, REM, Deep (N3), Core (N1+N2)**.
- Entrenamiento/validación con **PSG** (laboratorio y domicilio) y, en parte, **EEG en casa** con revisión experta.
- Evolución: mejoras 2024–2025 (por ejemplo iOS/watchOS 26) con **modelos base** a partir de **Apple Heart and Movement Study**, enfocados en **“quiet wake”** (vigilia muy inmóvil).
- Sigue basado en **acelerómetro** (incluye micro-movimientos de respiración), no en el desglose que la app tercera lea de HealthKit.

**sleep score (watchOS 26)**

- **No** está en el PDF de fases de la misma forma: la descomposición **50% duración / 30% regularidad de hora / 20% interrupciones** aparece en **prensa** (por ejemplo 9to5Mac citando a Apple). Tratarlo como descripción de producto, no como documento de ingeniería con la misma rigurosidad que el PDF de staging.

**Idea clave**: En Apple, **las fases** vienen de un **clasificador en el reloj**; **Salud/HealthKit** en la app de terceros recibe **muestras ya categorizadas** (como en VitrikFit). El **sleep score** de Apple es otra capa (más reciente) y con documentación pública distinta a la de staging.

---

## SleepWatch (Bodymatter)

**Qué declaran**

- Usa **Apple Watch** (acelerómetro, FC, HRV, SpO2, etc.) y opcionalmente **iPhone** (micrófono para ruidos, ronquidos).
- Métricas propias: **Total Sleep, Restful Sleep, Disruption, Rhythm, Heart Rate Dip, Sleeping HRV**, etc.
- **SleepWatch Score**: algoritmo “sofisticado” y comparación con **más de 100M de noches** de la comunidad (marketing en [sleepwatchapp.com](https://www.sleepwatchapp.com/features/)) — **sin fórmula abierta**.
- Posicionamiento: **asistente con IA** + coaching; resultados = **estimaciones**, no dispositivo médico.

**Idea clave**: Similar a Oura en **ecosistema de app**: muchas métricas compuestas y score global, pero **caja negra** respecto a pesos. Se apoya en datos del Watch (y a veces en audio) en lugar de reimplementar staging desde cero en solo el iPhone.

---

## Comparación rápida (diseño, no números exactos)

| Dimensión | Oura | Apple | SleepWatch |
| --- | --- | --- | --- |
| **Quién genera las fases** | Anillo + ML propio | Watch (acelerómetro + modelos Apple) | Watch + processing propio; integra Salud |
| **Señales típicas** | FC, HRV, temp, movimiento, RR | Acelerómetro (oficial para staging) + resto ecosistema | Watch + iPhone; métricas “Restful/Disruption/Rhythm” |
| **Score** | 7 factores, pesos no públicos | Score reciente: diseño 50/30/20 (prensa) | Score vs comunidad, pesos no públicos |
| **Transparencia académica** | Papers + % vs PSG | PDF Apple detallado en staging | Marketing + “estimaciones” |

---

## Cómo se relaciona con VitrikFit

> Sección **verificada contra el código el 2026-08-15** (`Core/SleepQualityScoring.swift`). La
> versión anterior citaba proporciones deep/REM de 17.5% / 22.5% que ya no existen en el código:
> el scoring evolucionó de puntos de referencia fijos a bandas.

**Las fases no las calcula la app.** VitrikFit lee categorías de HealthKit (`sleepAnalysis`) ya
producidas por el sistema y el Watch. Es decir, hereda el clasificador de Apple descrito arriba —
acelerómetro, epochs de 30 s, cuatro estados. Lo que la app aporta es la **capa de puntuación**
por encima de esas muestras.

### Composite real

`SleepQualityScoring` combina cuatro subscores con pesos fijos:

| Componente | Peso |
|---|---|
| Duración vs meta | **60%** |
| Continuidad | **20%** |
| REM | **10%** |
| Deep | **10%** |

Sobre eso actúan cuatro reglas más:

- **Curvatura por debajo de la meta** (`belowGoalCurvature = 1.45`): dormir de menos se penaliza
  de forma no lineal, `ratio^1.45`. Quedarse corto duele progresivamente más.
- **Bandas óptimas de fase**, como % del tiempo total dormido — no valores puntuales:
  deep **10%–28%**, REM **15%–32%**. Aproximan las referencias de la AASM.
- **Neutrales cuando falta el dato**, en lugar de castigar: sin muestras `awake` la continuidad
  vale 78; sin desglose de fases (solo `asleep` genérico) las fases valen 72. Es una decisión
  deliberada: no penalizar al usuario por lo que su hardware no reporta.
- **Ajuste por confianza** (`confidenceDeltaPoints = 8.0`): `sleepConfidence` —que produce
  `SleepSessionFilter`— suma o resta hasta 8 puntos respecto a un centro de 0.5, en lugar de
  multiplicar el score entero.

### Comparación honesta con los tres

Contra **Apple** (50% duración / 30% regularidad / 20% interrupciones), VitrikFit es
estructuralmente muy parecido: ambos son composites ponderados dominados por la duración. Las
diferencias reales son dos — VitrikFit carga más en duración (60 vs 50) y **no puntúa la
regularidad de horario dentro del score de sueño**, mientras que Apple le da un 30%. En cambio
VitrikFit sí puntúa las fases (20% entre REM y deep), que Apple no incluye en su score.

Contra **Oura**, la diferencia es de fondo: Oura genera sus propias fases con hardware y ML
propios, y su score tiene 7 contribuidores con pesos no públicos. VitrikFit tiene 4 componentes
con pesos abiertos en el código, sobre fases de terceros.

Contra **SleepWatch**, VitrikFit no usa comparación con una comunidad ni audio.

**La ventaja competitiva de VitrikFit no está en el score de sueño**, que es más simple que
cualquiera de los tres. Está en lo que hace *después*: alimentar el recovery score y **ajustar el
entrenamiento del día**. Ninguno de los tres cierra ese bucle.

---

## Fuentes útiles

- Oura: [Sleep Score (blog)](https://ouraring.com/blog/sleep-score/), [Sleep Contributors (help)](https://support.ouraring.com/hc/en-us/articles/360057792293-Sleep-Contributors), posts sobre **Sleep Staging 2.0**.
- Apple: [PDF Sleep Stages Oct 2025](https://www.apple.com/health/pdf/Estimating_Sleep_Stages_from_Apple_Watch_Oct_2025.pdf).
- SleepWatch: [Features / SleepWatch Score](https://www.sleepwatchapp.com/features/).

---

## Posibles siguientes pasos de producto (opcional)

- Alinear el **lenguaje de la app** con lo que el usuario suele esperar si viene de Oura/Apple (sin copiar marcas).
- Acotar internamente qué parte del score viene de **datos HealthKit** vs **reglas en app**; no hace falta publicar fórmulas al usuario.
