# Gymnasium Migration Code Examples

This document provides side-by-side code comparisons for the migration.

---

## Table of Contents

1. [Sphere Backend (Python)](#sphere-backend-python)
2. [Proto Definitions](#proto-definitions)
3. [Gold Core (Go)](#gold-core-go)
4. [Agent Examples](#agent-examples)

---

## Sphere Backend (Python)

### server.py - StepEnv Method

**BEFORE (Gym):**
```python
def StepEnv(self, request, context):
    env = self.envs[request.id]
    env.render()
    
    observation, reward, done, info = env.step(request.action)
    
    if not isinstance(observation, np.ndarray):
        self.logger.debug("reshaping observation to tensor")
        observation = np.array(observation)
    
    observation = encode_tensor(observation)
    goal = Tensor()
    if hasattr(env, "goal"):
        goal = encode_tensor(env.goal)
    
    s = Struct()
    s.update(info)
    
    return StepEnvResponse(
        observation=observation,
        reward=reward,
        done=done,  # Single boolean
        goal=goal,
        info=s
    )
```

**AFTER (Gymnasium):**
```python
def StepEnv(self, request, context):
    env = self.envs[request.id]
    env.render()
    
    # New step API returns 5 values
    observation, reward, terminated, truncated, info = env.step(request.action)
    
    if not isinstance(observation, np.ndarray):
        self.logger.debug("reshaping observation to tensor")
        observation = np.array(observation)
    
    observation = encode_tensor(observation)
    goal = Tensor()
    if hasattr(env, "goal"):
        goal = encode_tensor(env.goal)
    
    s = Struct()
    s.update(info)
    
    return StepEnvResponse(
        observation=observation,
        reward=reward,
        terminated=terminated,  # NEW: Natural episode end
        truncated=truncated,    # NEW: External constraint
        goal=goal,
        info=s
    )
```

---

### server.py - ResetEnv Method

**BEFORE (Gym):**
```python
def ResetEnv(self, request, context):
    env = self.envs[request.id]
    
    observation = env.reset()  # Returns only observation
    
    if not isinstance(observation, np.ndarray):
        self.logger.debug("reshaping observation to tensor")
        observation = np.array(observation)
    
    goal = Tensor()
    if hasattr(env, "goal"):
        goal = encode_tensor(env.goal)
    
    return ResetEnvResponse(
        observation=encode_tensor(observation),
        goal=goal
    )
```

**AFTER (Gymnasium):**
```python
def ResetEnv(self, request, context):
    env = self.envs[request.id]
    
    # New reset API returns observation and info
    # Also supports seeding
    seed = request.seed if hasattr(request, 'seed') else None
    observation, info = env.reset(seed=seed)
    
    if not isinstance(observation, np.ndarray):
        self.logger.debug("reshaping observation to tensor")
        observation = np.array(observation)
    
    goal = Tensor()
    if hasattr(env, "goal"):
        goal = encode_tensor(env.goal)
    
    s = Struct()
    s.update(info)
    
    return ResetEnvResponse(
        observation=encode_tensor(observation),
        goal=goal,
        info=s  # NEW: Info dict from reset
    )
```

---

### server.py - CreateEnv Method

**BEFORE (Gym):**
```python
def CreateEnv(self, request, context):
    self.logger.info("creating env")
    id = str(uuid.uuid4())
    
    try:
        # Create environment
        self.envs[id] = gym.make(request.model_name)
        
        # Apply wrappers after creation
        for w in request.wrappers:
            if w.HasField("deepmind_atari_wrapper"):
                self.envs[id] = wrap_deepmind(self.envs[id], ...)
    except:
        # Error handling
        pass
    
    return CreateEnvResponse(environment=self._get_env(id))
```

**AFTER (Gymnasium):**
```python
def CreateEnv(self, request, context):
    self.logger.info("creating env")
    id = str(uuid.uuid4())
    
    # Determine render mode from request
    render_mode = None
    if hasattr(request, 'render_mode'):
        render_mode = request.render_mode
    
    try:
        # Create environment with render mode
        self.envs[id] = gym.make(
            request.model_name,
            render_mode=render_mode  # NEW: Set at creation
        )
        
        # Apply wrappers after creation
        for w in request.wrappers:
            if w.HasField("deepmind_atari_wrapper"):
                self.envs[id] = wrap_deepmind(self.envs[id], ...)
    except:
        # Error handling
        pass
    
    return CreateEnvResponse(environment=self._get_env(id))
```

---

## Proto Definitions

### env.proto - StepEnvResponse

**BEFORE:**
```protobuf
message StepEnvResponse {
    Tensor observation = 1;
    float reward = 2;
    bool done = 3;           // Ambiguous!
    Tensor goal = 4;
    google.protobuf.Struct info = 5;
}
```

**AFTER:**
```protobuf
message StepEnvResponse {
    Tensor observation = 1;
    float reward = 2;
    bool terminated = 3;     // Natural episode end
    bool truncated = 4;      // External constraint (e.g., time limit)
    Tensor goal = 5;
    google.protobuf.Struct info = 6;
}
```

---

### env.proto - ResetEnvRequest

**BEFORE:**
```protobuf
message ResetEnvRequest {
    string id = 1;
}
```

**AFTER:**
```protobuf
message ResetEnvRequest {
    string id = 1;
    int32 seed = 2;  // NEW: Optional seed parameter
}
```

---

### env.proto - ResetEnvResponse

**BEFORE:**
```protobuf
message ResetEnvResponse {
    Tensor observation = 1;
    Tensor goal = 2;
}
```

**AFTER:**
```protobuf
message ResetEnvResponse {
    Tensor observation = 1;
    Tensor goal = 2;
    google.protobuf.Struct info = 3;  // NEW: Info from reset
}
```

---

## Gold Core (Go)

### env.go - Outcome Struct

**BEFORE:**
```go
// Outcome of taking an action.
type Outcome struct {
    // Observation of the current state.
    Observation *tensor.Dense

    // Action that was taken
    Action int

    // Reward from action.
    Reward float32

    // Whether the environment is done.
    Done bool
}
```

**AFTER:**
```go
// Outcome of taking an action.
type Outcome struct {
    // Observation of the current state.
    Observation *tensor.Dense

    // Action that was taken
    Action int

    // Reward from action.
    Reward float32

    // Terminated indicates the episode ended naturally (task success/failure).
    // Example: agent reached goal, fell over, lost game, etc.
    // When terminated=true, NO bootstrapping should occur in RL algorithms.
    Terminated bool

    // Truncated indicates the episode ended due to external constraints.
    // Example: time limit reached, step limit exceeded, out of bounds, etc.
    // When truncated=true, bootstrapping SHOULD occur in RL algorithms.
    Truncated bool
}

// Done returns true if the episode has ended for any reason.
// This is a convenience method equivalent to: Terminated || Truncated
func (o *Outcome) Done() bool {
    return o.Terminated || o.Truncated
}
```

---

### env.go - Step Method

**BEFORE:**
```go
func (e *Env) Step(value int) (*Outcome, error) {
    ctx := context.Background()
    resp, err := e.Client.StepEnv(ctx, &spherev1alpha.StepEnvRequest{
        Id:     e.Id,
        Action: int32(value),
    })
    if err != nil {
        return nil, err
    }
    
    observation := resp.Observation.Dense()
    if e.Normalizer != nil {
        observation, err = e.Normalizer.Norm(observation)
        if err != nil {
            return nil, err
        }
    }
    
    return &Outcome{
        Observation: observation,
        Action:      value,
        Reward:      resp.Reward,
        Done:        resp.Done,  // Single boolean
    }, nil
}
```

**AFTER:**
```go
func (e *Env) Step(value int) (*Outcome, error) {
    ctx := context.Background()
    resp, err := e.Client.StepEnv(ctx, &spherev1alpha.StepEnvRequest{
        Id:     e.Id,
        Action: int32(value),
    })
    if err != nil {
        return nil, err
    }
    
    observation := resp.Observation.Dense()
    if e.Normalizer != nil {
        observation, err = e.Normalizer.Norm(observation)
        if err != nil {
            return nil, err
        }
    }
    
    return &Outcome{
        Observation: observation,
        Action:      value,
        Reward:      resp.Reward,
        Terminated:  resp.Terminated,  // NEW
        Truncated:   resp.Truncated,   // NEW
    }, nil
}
```

---

### env.go - InitialState Struct

**BEFORE:**
```go
// InitialState of the environment.
type InitialState struct {
    // Observation of the environment.
    Observation *tensor.Dense

    // Goal if present.
    Goal *tensor.Dense
}
```

**AFTER:**
```go
// InitialState of the environment.
type InitialState struct {
    // Observation of the environment.
    Observation *tensor.Dense

    // Goal if present.
    Goal *tensor.Dense
    
    // Info contains auxiliary information from reset.
    Info map[string]interface{}
}
```

---

### env.go - Reset Method

**BEFORE:**
```go
func (e *Env) Reset() (init *InitialState, err error) {
    ctx := context.Background()
    resp, err := e.Client.ResetEnv(ctx, &spherev1alpha.ResetEnvRequest{
        Id: e.Id,
    })
    if err != nil {
        return nil, err
    }
    
    observation := resp.Observation.Dense()
    var goal *tensor.Dense
    if resp.GetGoal().Data != nil {
        goal = resp.GetGoal().Dense()
    }
    
    if e.Normalizer != nil {
        observation, err = e.Normalizer.Norm(observation)
        if err != nil {
            return nil, err
        }
    }
    
    return &InitialState{
        Observation: observation,
        Goal:        goal,
    }, nil
}
```

**AFTER:**
```go
func (e *Env) Reset() (init *InitialState, err error) {
    ctx := context.Background()
    resp, err := e.Client.ResetEnv(ctx, &spherev1alpha.ResetEnvRequest{
        Id: e.Id,
        // TODO: Add seed support
        // Seed: seed,
    })
    if err != nil {
        return nil, err
    }
    
    observation := resp.Observation.Dense()
    var goal *tensor.Dense
    if resp.GetGoal().Data != nil {
        goal = resp.GetGoal().Dense()
    }
    
    // NEW: Parse info dict
    info := make(map[string]interface{})
    if resp.Info != nil {
        info = resp.Info.AsMap()
    }
    
    if e.Normalizer != nil {
        observation, err = e.Normalizer.Norm(observation)
        if err != nil {
            return nil, err
        }
    }
    
    return &InitialState{
        Observation: observation,
        Goal:        goal,
        Info:        info,  // NEW
    }, nil
}
```

---

## Agent Examples

### DeepQ - Training Loop

**BEFORE:**
```go
// experiments/cartpole/main.go
for i := 0; i < totalSteps; i++ {
    action, err := agent.Action(state.Observation)
    if err != nil {
        log.Fatal(err)
    }
    
    outcome, err := env.Step(action)
    if err != nil {
        log.Fatal(err)
    }
    
    agent.Remember(state.Observation, action, outcome)
    
    if outcome.Done {  // Ambiguous!
        state, err = env.Reset()
        if err != nil {
            log.Fatal(err)
        }
        episodeCounter++
        continue
    }
    
    state.Observation = outcome.Observation
}
```

**AFTER:**
```go
// experiments/cartpole/main.go
for i := 0; i < totalSteps; i++ {
    action, err := agent.Action(state.Observation)
    if err != nil {
        log.Fatal(err)
    }
    
    outcome, err := env.Step(action)
    if err != nil {
        log.Fatal(err)
    }
    
    agent.Remember(state.Observation, action, outcome)
    
    // Clear: episode ended for any reason
    if outcome.Terminated || outcome.Truncated {
        state, err = env.Reset()
        if err != nil {
            log.Fatal(err)
        }
        episodeCounter++
        continue
    }
    
    state.Observation = outcome.Observation
}
```

---

### DeepQ - Target Calculation (CRITICAL!)

**BEFORE (INCORRECT):**
```go
// agent.go - Learn method
func (a *Agent) Learn() error {
    // ... sample batch from memory ...
    
    for _, event := range batch {
        var target float32
        
        // WRONG: Treats all "done" the same!
        if event.Done {
            target = event.Reward  // No bootstrapping
        } else {
            // Get max Q value for next state
            qValues, err := a.Policy.Predict(event.Observation)
            maxQ := maxQValue(qValues)
            target = event.Reward + a.Gamma * maxQ
        }
        
        targets = append(targets, target)
    }
    
    // Update network...
}
```

**AFTER (CORRECT):**
```go
// agent.go - Learn method
func (a *Agent) Learn() error {
    // ... sample batch from memory ...
    
    for _, event := range batch {
        var target float32
        
        // CORRECT: Distinguish termination from truncation
        if event.Terminated {
            // Episode naturally ended - no future value
            target = event.Reward
        } else {
            // Episode ongoing OR truncated - bootstrap!
            qValues, err := a.Policy.Predict(event.Observation)
            maxQ := maxQValue(qValues)
            target = event.Reward + a.Gamma * maxQ
        }
        
        targets = append(targets, target)
    }
    
    // Update network...
}
```

**Why this matters:**
When an episode hits a time limit (truncated), there IS future value to be gained. The old code incorrectly set `target = reward` for time limits, biasing the value function downward.

---

### DeepQ - Memory Event Struct

**BEFORE:**
```go
// memory.go
type Event struct {
    State       *tensor.Dense
    Action      int
    Reward      float32
    Observation *tensor.Dense
    Done        bool  // Ambiguous
}
```

**AFTER:**
```go
// memory.go
type Event struct {
    State       *tensor.Dense
    Action      int
    Reward      float32
    Observation *tensor.Dense
    Terminated  bool  // Natural episode end
    Truncated   bool  // External constraint
}
```

---

### PPO - Mask Calculation (CRITICAL!)

**BEFORE (INCORRECT):**
```go
// memory.go
func (m *Memory) Track(outcome *envv1.Outcome, ...) error {
    // WRONG: Mask is 0 for ANY done (including time limits)
    mask := float32(num.BoolToInt(!outcome.Done))
    
    m.Observations = append(m.Observations, observation)
    m.Actions = append(m.Actions, action)
    m.Rewards = append(m.Rewards, outcome.Reward)
    m.Masks = append(m.Masks, mask)
    m.Values = append(m.Values, value)
    m.LogProbs = append(m.LogProbs, logProb)
    
    return nil
}
```

**AFTER (CORRECT):**
```go
// memory.go
func (m *Memory) Track(outcome *envv1.Outcome, ...) error {
    // CORRECT: Mask is 0 ONLY on termination
    // On truncation, we still want to bootstrap!
    mask := float32(num.BoolToInt(!outcome.Terminated))
    
    m.Observations = append(m.Observations, observation)
    m.Actions = append(m.Actions, action)
    m.Rewards = append(m.Rewards, outcome.Reward)
    m.Masks = append(m.Masks, mask)
    m.Values = append(m.Values, value)
    m.LogProbs = append(m.LogProbs, logProb)
    
    return nil
}
```

**Why this matters:**
PPO uses masks for computing advantages and returns. Setting mask=0 on time limits (truncation) incorrectly prevents bootstrapping, leading to biased value estimates and degraded performance.

---

### HER - Hindsight Relabeling

**BEFORE:**
```go
// agent.go
func (a *Agent) hindsightExperience(events []*Event, ...) {
    for i, event := range events {
        // Check if goal achieved
        goalAchieved := checkGoalAchieved(event.Observation, desiredGoal)
        
        if goalAchieved {
            event.Reward = 0.0  // Success reward
            event.Done = true   // Mark as done
        }
        
        // Store modified event
        a.Memory.Add(event)
    }
}
```

**AFTER:**
```go
// agent.go
func (a *Agent) hindsightExperience(events []*Event, ...) {
    for i, event := range events {
        // Check if goal achieved
        goalAchieved := checkGoalAchieved(event.Observation, desiredGoal)
        
        if goalAchieved {
            event.Reward = 0.0      // Success reward
            event.Terminated = true // Mark as terminated (goal reached)
            event.Truncated = false // Not truncated
        } else if event.Truncated {
            // Episode was truncated, not terminated
            // Don't change terminated/truncated flags
        }
        
        // Store modified event
        a.Memory.Add(event)
    }
}
```

---

### Simple Training Loop Pattern

**BEFORE:**
```go
// Generic pattern used across all agents
episodeReward := 0.0
for {
    action, _ := agent.Action(state)
    outcome, _ := env.Step(action)
    
    agent.Update(outcome)
    episodeReward += outcome.Reward
    
    if outcome.Done {
        break
    }
    state = outcome.Observation
}
```

**AFTER:**
```go
// Generic pattern - more explicit
episodeReward := 0.0
for {
    action, _ := agent.Action(state)
    outcome, _ := env.Step(action)
    
    agent.Update(outcome)
    episodeReward += outcome.Reward
    
    // Episode ended (either naturally or truncated)
    if outcome.Terminated || outcome.Truncated {
        if outcome.Terminated {
            // Natural ending - log differently?
        }
        break
    }
    state = outcome.Observation
}
```

---

## Testing Examples

### Unit Test - Step Returns

**BEFORE:**
```go
func TestStep(t *testing.T) {
    env := setupTestEnv()
    state, _ := env.Reset()
    
    outcome, err := env.Step(0)
    assert.NoError(t, err)
    assert.NotNil(t, outcome.Observation)
    assert.IsType(t, float32(0), outcome.Reward)
    assert.IsType(t, bool(false), outcome.Done)
}
```

**AFTER:**
```go
func TestStep(t *testing.T) {
    env := setupTestEnv()
    state, _ := env.Reset()
    
    outcome, err := env.Step(0)
    assert.NoError(t, err)
    assert.NotNil(t, outcome.Observation)
    assert.IsType(t, float32(0), outcome.Reward)
    assert.IsType(t, bool(false), outcome.Terminated)
    assert.IsType(t, bool(false), outcome.Truncated)
    
    // Test convenience method
    assert.Equal(t, outcome.Terminated || outcome.Truncated, outcome.Done())
}
```

---

### Integration Test - Episode Completion

**BEFORE:**
```go
func TestEpisodeCompletion(t *testing.T) {
    env := setupTestEnv()
    state, _ := env.Reset()
    
    steps := 0
    for steps < 1000 {
        outcome, _ := env.Step(env.SampleAction())
        steps++
        
        if outcome.Done {
            // Episode ended somehow
            break
        }
    }
    
    assert.Less(t, steps, 1000, "Episode should complete")
}
```

**AFTER:**
```go
func TestEpisodeCompletion(t *testing.T) {
    env := setupTestEnv()
    state, _ := env.Reset()
    
    steps := 0
    terminated := false
    truncated := false
    
    for steps < 1000 {
        outcome, _ := env.Step(env.SampleAction())
        steps++
        
        if outcome.Terminated || outcome.Truncated {
            terminated = outcome.Terminated
            truncated = outcome.Truncated
            break
        }
    }
    
    // Can now test WHY episode ended
    if truncated {
        t.Log("Episode hit time limit")
    }
    if terminated {
        t.Log("Episode ended naturally")
    }
    
    assert.Less(t, steps, 1000, "Episode should complete")
}
```

---

## Common Pitfalls to Avoid

### Pitfall 1: Using Done() Instead of Terminated

**WRONG:**
```go
// In learning algorithm
if event.Done() {  // BAD - this includes truncation!
    target = reward  // Won't bootstrap on time limits
}
```

**RIGHT:**
```go
// In learning algorithm  
if event.Terminated {  // GOOD - only natural endings
    target = reward
} else {
    target = reward + gamma * nextValue  // Bootstrap on truncation
}
```

---

### Pitfall 2: Not Updating Memory Structs

**WRONG:**
```go
// Forgetting to update Event struct
event := &Event{
    State:  state,
    Action: action,
    Reward: outcome.Reward,
    Done:   outcome.Done(),  // WRONG - still using old field
}
```

**RIGHT:**
```go
event := &Event{
    State:      state,
    Action:     action,
    Reward:     outcome.Reward,
    Terminated: outcome.Terminated,  // RIGHT
    Truncated:  outcome.Truncated,   // RIGHT
}
```

---

### Pitfall 3: Not Handling Reset Info

**WRONG:**
```go
// Ignoring info from reset
state, _ := env.Reset()
// Info is lost!
```

**RIGHT:**
```go
// Capture and potentially use reset info
state, _ := env.Reset()
if state.Info != nil {
    // Log, process, or store info
    log.Debugf("Reset info: %v", state.Info)
}
```

---

*This document will be updated as implementation proceeds.*
