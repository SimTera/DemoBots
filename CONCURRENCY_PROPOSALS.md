# Propuestas de refactor para Concurrencia Estricta (Swift 6, julio 2026)

> **Objetivo:** eliminar los 18 errores de compilación que quedan en `Sources/SceneManagement/*` y estabilizar el patrón que ya usas en `Sources/States/Beam*State.swift`.
>
> **No modifico código en este documento.** Todas las propuestas quedan aquí para que las apliques tú.

---

## 1. Diagnóstico: por qué fallan los `GKState` y `GKComponent`

`GKState`, `GKStateMachine`, `GKComponent`, `GKAgent`, `GKBehavior`, `GKRule`… son clases Objective-C importadas desde **GameplayKit**. El framework **no ha sido anotado** con isolation de Swift 6, así que **todos sus métodos son `nonisolated`** en la vista del compilador.

Tu proyecto (o al menos el target) está usando la inferencia `MainActor` por defecto (probablemente `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` o `-default-isolation MainActor`). Eso convierte cualquier `class`/`init`/`func` sin anotación explícita en `@MainActor`.

Cuando escribes:

```swift
class SceneLoaderInitialState: GKState {          // ← implícitamente @MainActor
    init(sceneLoader: SceneLoader) { … }          // ← @MainActor
    override func didEnter(from previousState: GKState?) { … } // ← @MainActor
    override func isValidNextState(_ stateClass: AnyClass) -> Bool { … } // ← @MainActor
}
```

… el override cambia el aislamiento respecto a la base `nonisolated`. En Swift 6 estricto eso ya no es un warning: es un error duro (`Main actor-isolated instance method '…' has different actor isolation from nonisolated overridden declaration`). Los 12 errores repetidos en los `SceneLoader*State.swift` son exactamente ese patrón, y son consecuencia de que **no aplicaste el mismo remedio que ya inventaste para los `Beam*State`**.

---

## 2. El patrón "correcto" (lo que ya haces bien en `BeamIdleState`)

En `Sources/States/BeamIdleState.swift` ya llegaste a la fórmula que funciona con GameplayKit + Swift 6:

```swift
class BeamIdleState: GKState {
    unowned var beamComponent: BeamComponent

    @available(*, unavailable, message: "Use init(beamComponent:) instead.")
    override nonisolated init() { fatalError(…) }

    nonisolated required init(beamComponent: BeamComponent) {
        self.beamComponent = beamComponent
        super.init()
    }

    nonisolated override func update(deltaTime seconds: TimeInterval) {
        MainActor.assumeIsolated {
            super.update(deltaTime: seconds)
            if beamComponent.isTriggered { stateMachine?.enter(BeamFiringState.self) }
        }
    }

    nonisolated override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return stateClass is BeamFiringState.Type
    }
}
```

**Reglas de la fórmula:**

1. La **clase** puede quedarse sin anotar; lo importante son los métodos.
2. Todo `override` de un método de `GKState` va marcado `nonisolated override func …`.
3. El `init` también va `nonisolated` (incluye el `override init()` bloqueado con `@available(*, unavailable)`).
4. Dentro del cuerpo, si tocas propiedades `@MainActor` (SpriteKit, entities, `beamComponent`), envuelves con `MainActor.assumeIsolated { … }`.
5. La `assumeIsolated` es segura **si en tiempo de ejecución la llamada realmente proviene del hilo main** (el game loop de SpriteKit siempre lo hace — ver [Use SpriteKit Objects within Scene Delegate Callbacks](https://developer.apple.com/documentation/spritekit/use-spritekit-objects-within-scene-delegate-callbacks)).

Esto es el patrón que Apple documenta en [Adopting strict concurrency in Swift 6 apps](https://developer.apple.com/documentation/Swift/AdoptingSwift6) para adaptar frameworks legacy sin anotar.

---

## 3. Aplicación directa a los 12 errores de `SceneLoader*State.swift`

Todos los errores de esos 5 ficheros se resuelven pegando la fórmula del `Beam`. Los cambios que necesitarás hacer (no los aplico yo):

### 3.1 `SceneLoaderInitialState.swift`

- Línea 11 (init): `nonisolated init(sceneLoader: SceneLoader)`
- Línea 24 (`didEnter(from:)`): `nonisolated override func didEnter(from previousState: GKState?)` + envolver el cuerpo en `MainActor.assumeIsolated { … }` porque toca `sceneLoader.sceneMetadata` y `stateMachine!.enter(…)`.
- Línea 36 (`isValidNextState`): `nonisolated override func isValidNextState(_ stateClass: AnyClass) -> Bool`. El cuerpo es puro chequeo de tipos → **no necesita** `assumeIsolated`.

### 3.2 `SceneLoaderResourcesAvailableState.swift`

- Línea 11 (init): `nonisolated init(sceneLoader: SceneLoader)`
- Línea 24 (`isValidNextState`): `nonisolated override func …` sin `assumeIsolated`.

### 3.3 `SceneLoaderDownloadFailedState.swift`

- Línea 11 (init): `nonisolated init(sceneLoader: SceneLoader)`
- Línea 24 (`didEnter(from:)`): `nonisolated override func …` + `MainActor.assumeIsolated { super.didEnter(from: previousState); sceneLoader.progress = nil; NotificationCenter.default.post(…) }`.
- Línea 34 (`isValidNextState`): `nonisolated override func …`.

### 3.4 `SceneLoaderDownloadingResourcesState.swift`

- Línea 11 (init): `nonisolated init(sceneLoader: SceneLoader)`
- Línea 27 (`didEnter(from:)`): `nonisolated override func …` + `MainActor.assumeIsolated { super.didEnter(…); sceneLoader.error = nil; beginDownloadingScene() }`.
- Línea 35 (`isValidNextState`): `nonisolated override func …`.
- **Warning línea 65 (`NSBundleResourceRequest` no `Sendable`)**: el closure `beginAccessingResources { error in … }` es `@Sendable`, y captura `bundleResourceRequest`. Solución moderna: cambiar a la API `async` de iOS 18+:

  ```swift
  private func beginDownloadingScene() {
      let request = NSBundleResourceRequest(tags: sceneLoader.sceneMetadata.onDemandResourcesTags)
      sceneLoader.bundleResourceRequest = request
      Task { @MainActor in
          do {
              try await request.beginAccessingResources()
              if self.enterPreparingStateWhenFinished {
                  self.stateMachine!.enter(SceneLoaderPreparingResourcesState.self)
              } else {
                  self.stateMachine!.enter(SceneLoaderResourcesAvailableState.self)
              }
          } catch {
              request.endAccessingResources()
              self.sceneLoader.error = error
              self.stateMachine!.enter(SceneLoaderDownloadFailedState.self)
          }
      }
  }
  ```

  Con esto el warning de `@Sendable` desaparece porque `Task { @MainActor in … }` es MainActor-aislado y no hay closure `@Sendable`.

### 3.5 `SceneLoaderPreparingResourcesState.swift`

- Línea 11 (init): `nonisolated init(sceneLoader: SceneLoader)`
- Línea 55 (`didEnter(from:)`): `nonisolated override func …` + `MainActor.assumeIsolated { super.didEnter(…); loadResourcesAsynchronously() }`.
- Línea 62 (`isValidNextState`): `nonisolated override func …` — su cuerpo lee `sceneLoader.scene`, así que **sí** necesita `MainActor.assumeIsolated { … }` alrededor del `switch`.
- **Línea 32 (`Call to main actor-isolated instance method 'cancel()' in a synchronous nonisolated context`)**: el `progress.cancellationHandler` es un `@Sendable () -> Void`. Dos soluciones:

  ```swift
  progress.cancellationHandler = { [weak self] in
      guard let self else { return }
      Task { @MainActor in self.cancel() }
  }
  ```

  O más directo (dado que SpriteKit garantiza que estos handlers llegan en el main queue en la práctica):

  ```swift
  progress.cancellationHandler = { [weak self] in
      MainActor.assumeIsolated { self?.cancel() }
  }
  ```

  Yo iría con el `Task { @MainActor in … }` porque `Progress` **no garantiza** en qué hilo dispara el handler; `assumeIsolated` puede crashear si no lo está.

- **Línea 93 (`Cannot convert value of type 'Int' to expected argument type 'Int64'`)**: es un error trivial de tipos, sin relación con concurrencia. Basta con:

  ```swift
  let loadingProgress = Progress(totalUnitCount: Int64(sceneMetadata.loadableTypes.count + 1))
  ```

---

## 4. Los dos errores en `SceneLoader.swift` (líneas 66-67)

```
error: Main actor-isolated property 'requestedForPresentation' can not be mutated from a Sendable closure
error: Main actor-isolated property 'error' can not be mutated from a Sendable closure
```

Vienen del `progress.cancellationHandler` en la línea 64:

```swift
progress.cancellationHandler = { [unowned self] in
    self.requestedForPresentation = false     // ← MainActor
    self.error = NSError(…)                    // ← MainActor
    NotificationCenter.default.post(…)
}
```

Misma solución que en §3.5:

```swift
progress.cancellationHandler = { [weak self] in
    Task { @MainActor in
        guard let self else { return }
        self.requestedForPresentation = false
        self.error = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
        NotificationCenter.default.post(name: .SceneLoaderDidFailNotification, object: self)
    }
}
```

**Nota importante:** cambiar `[unowned self]` a `[weak self]` es intencional — un `Task` puede sobrevivir al `SceneLoader` durante un frame y `[unowned]` crashearía.

---

## 5. Sobre tu intuición del **enum para el Beam**

> *"cambiando alguna parte de codigo como el estado de rayos a un enum o algo asi se podria mejorar una parte de este"*

Tu intuición es **correcta y pertinente**, pero con un matiz importante:

### 5.1 Qué NO se puede hacer

**No puedes reemplazar `GKStateMachine` con un `enum`**. `GKStateMachine.init(states:)` exige un array de instancias `GKState` (clases). Un enum-based state machine implicaría abandonar GameplayKit para el subsistema del Beam.

### 5.2 Qué SÍ deberías hacer (y quitaría el peor parche)

El punto donde tu diseño actual se retuerce feo es en `BeamFiringState.willExit(to:)` (líneas 129–153 de `BeamFiringState.swift`):

```swift
if shouldShowIdle {
    beamComponent.beamNode.update(
        withBeamState: BeamIdleState(beamComponent: beamComponent),   // ← instancia falsa
        source: beamComponent.playerBot
    )
} else if shouldShowCooling {
    beamComponent.beamNode.update(
        withBeamState: BeamCoolingState(beamComponent: beamComponent), // ← instancia falsa
        source: beamComponent.playerBot
    )
}
```

Estás creando `GKState`s temporales solo para pasarlos como discriminador a `BeamNode.update`. Y en `BeamCoolingState.willExit` haces el truco `nonisolated(unsafe) let next = nextState` — que como bien anotas es un parche.

**La causa raíz**: `BeamNode.update(withBeamState state: GKState, …)` acepta un `GKState` y hace un `switch` con `case is BeamIdleState: … case is BeamFiringState: … case is BeamCoolingState: …`. Un `GKState` (clase NSObject `nonisolated`) cruzando entre isolations no es `Sendable`.

**Propuesta enum-based (para el nodo visual, no para el state machine)**:

Introduce un tipo puramente descriptivo:

```swift
enum BeamVisualState: Sendable {
    case idle
    case firing(target: TaskBot?, debugArc: Bool)
    case cooling
}
```

Y cambia la firma de `BeamNode.update`:

```swift
func update(state: BeamVisualState, source: PlayerBot) { … }
```

Ahora los `willExit`/`didEnter` de los `Beam*State` solo mapean su transición al enum y pasan el enum. `BeamVisualState` **sí** es `Sendable`, cruza main-actor sin conflicto, y los estados `GKState` siguen viviendo con su rol de "lógica" mientras el nodo tiene su rol de "presentación".

Beneficios:

- Desaparecen las **instancias temporales** en `willExit`.
- Desaparece el `nonisolated(unsafe) let next = nextState`.
- El `switch` en `BeamNode` se vuelve exhaustivo (el compilador te avisa si añades un estado nuevo).
- `BeamNode` deja de acoplarse al ciclo de vida de GameplayKit — es puro SpriteKit.

Coste: unas 15 líneas de código nuevas y un `switch` que traduce `Beam*State → BeamVisualState`.

**Yo lo haría.** Es exactamente el tipo de refactor que aplaudían las WWDC 2024/2025 al hablar de migración a Swift 6: **separar semántica de identidad de la de presentación**.

---

## 6. Sobre el `NotificationCenter` moderno en `SceneManager.swift` (líneas 299–325)

Lo que has hecho está **bien** en general: sustituir `addObserver(forName:…, using:)` (que tiene el problema de `@Sendable` + `Notification` no-Sendable) por:

```swift
loadingCompletedObserver = Task { @MainActor [weak self] in
    let stream = NotificationCenter.default
        .notifications(named: .SceneLoaderDidCompleteNotification)
        .compactMap { notification in notification.object as? SceneLoader }

    for await sceneLoader in stream {
        …
    }
}
```

Es el patrón oficial recomendado para NotificationCenter + async/await desde iOS 15/macOS 12. Un par de matices:

- El `.compactMap { … }` sobre el `AsyncSequence` de `NotificationCenter` **extrae el object dentro del stream** que no cruza a otro actor: **correcto**. Sortea el hecho de que `Notification` no es `Sendable`.
- Si en algún momento tienes que leer más cosas de `notification` (`userInfo`), tendrás que capturarlas también dentro del `compactMap` (o usar `notification.object as? SceneLoader` + otra propiedad como una tupla).
- El `deinit` con `loadingCompletedObserver?.cancel()` está correcto — `Task` retorna a la primera oportunidad al cancelar.

**Sin cambios propuestos aquí.** Este bloque está actualizado a estándares de julio 2026.

---

## 7. Cosas que **no** vi como error pero deberías vigilar

### 7.1 `SceneMetadata` marcado como `nonisolated struct`

Tu comentario dice *"añadido a nonisolated"*. Como es un `struct` con solo `let`s y almacena metatipos (`BaseScene.Type`, `ResourceLoadableType.Type`) — que no son `Sendable` automáticamente — puede que en el futuro el compilador te pida un `@unchecked Sendable`. Vigila cualquier warning nuevo al respecto.

### 7.2 `TaskBotBehavior: GKBehavior` con `override nonisolated init()`

Correcto y necesario, pero recuerda que **todos** los `static func behavior…` que crean instancias también deben poder llamarse desde un contexto nonisolated si `GKBehavior` lo es. Ahora mismo funcionan porque el contenido de los `static func` no toca nada MainActor-aislado, pero el día que quieras pasar `LevelScene` (MainActor) tendrás que envolver en `MainActor.assumeIsolated { … }`.

### 7.3 `BeamCoolingState: nonisolated final class … @unchecked Sendable`

Ojo con marcar `@unchecked Sendable` una clase con `var elapsedTime` mutable. Como el ciclo de update del state machine siempre corre en el main-thread desde el game loop de SpriteKit, es seguro **en la práctica**, pero es exactamente el tipo de "unchecked" que Apple recomienda documentar con un comentario `// SAFETY: …` explicando por qué es seguro. Podrías simplificarlo: en vez de `nonisolated final class … @unchecked Sendable`, dejarlo como tus otros dos hermanos (`class BeamCoolingState: GKState` sin `nonisolated` en la clase y con métodos `nonisolated override func`) para consistencia visual con `BeamIdleState` y `BeamFiringState`.

### 7.4 Consistencia entre los tres `Beam*State`

Los tres archivos usan tres estilos ligeramente distintos:

- `BeamIdleState`: clase por defecto + métodos `nonisolated override func`.
- `BeamFiringState`: clase por defecto + métodos `nonisolated override func` + un método MainActor puro (`updateBeamNode(_:)`).
- `BeamCoolingState`: **clase entera `nonisolated final … @unchecked Sendable`** + métodos que ya no llevan `nonisolated` explícito.

Los tres compilan, pero son tres patrones distintos para el mismo problema. Recomiendo alinearlos al patrón de `BeamIdleState`, que es el más limpio y el que se generaliza mejor al resto del proyecto (`GroundBot*State`, `FlyingBot*State`, `PlayerBot*State`, `SceneLoader*State`, etc.).

---

## 8. Resumen priorizado de qué tocar

| Orden | Archivo | Cambio | Motivación |
|------:|---------|--------|------------|
| 1 | `SceneLoaderInitialState.swift` | `nonisolated init`, `nonisolated override func` en ambos métodos, `MainActor.assumeIsolated` en `didEnter` | Rompe 3 errores |
| 2 | `SceneLoaderResourcesAvailableState.swift` | Idem (solo tiene `isValidNextState`) | 2 errores |
| 3 | `SceneLoaderDownloadFailedState.swift` | Idem + `assumeIsolated` en `didEnter` | 3 errores |
| 4 | `SceneLoaderDownloadingResourcesState.swift` | Idem + refactor de `beginDownloadingScene` a `async` | 3 errores + 1 warning |
| 5 | `SceneLoaderPreparingResourcesState.swift` | Idem + `Task { @MainActor in cancel() }` en el `cancellationHandler` + fix `Int64` en línea 93 | 4 errores |
| 6 | `SceneLoader.swift` (líneas 64–72) | `Task { @MainActor in … }` en el `cancellationHandler` de `progress` + cambiar `[unowned]` a `[weak]` | 2 errores |
| 7 | `BeamNode.update(withBeamState:)` | Refactor a `enum BeamVisualState: Sendable` y adaptar los tres `Beam*State.willExit` | Quita el `nonisolated(unsafe)` y las instancias falsas |
| 8 | Los tres `Beam*State` | Alinear al patrón de `BeamIdleState` | Consistencia y mantenimiento |

Los pasos 1–6 son mecánicos y quitan **los 18 errores**. Los pasos 7 y 8 son mejoras arquitectónicas.

---

## 9. Regla mnemotécnica para lo que queda por migrar

Cada vez que veas una subclase de una clase de GameplayKit (`GKState`, `GKComponent`, `GKAgent`, `GKBehavior`, `GKRule`) o SpriteKit legacy que **no** conforme `Sendable` o `@MainActor` en la documentación de Apple:

1. **Init `nonisolated`**.
2. **Cada `override func` `nonisolated`**.
3. **Cuerpo dentro de `MainActor.assumeIsolated { … }` cuando toque el mundo SpriteKit / tus entidades**.
4. **Nada de `nonisolated(unsafe)`** — si aparece, es señal de que estás cruzando un valor no-Sendable y merece un tipo intermedio `Sendable` (ver §5.2).
5. **Callbacks `@Sendable` legacy** (`Progress.cancellationHandler`, `beginAccessingResources`, closures de bloques Objective-C) → sustituir por `Task { @MainActor in … }`.

Con eso deberías poder rematar el resto del proyecto sin sobresaltos.
