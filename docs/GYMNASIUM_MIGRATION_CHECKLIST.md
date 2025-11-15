# Gymnasium Migration Quick Checklist

Quick reference for migration progress. See [GYMNASIUM_MIGRATION_PLAN.md](./GYMNASIUM_MIGRATION_PLAN.md) for full details.

## Phase Status

- [x] **Phase 1:** Research & Planning (1 day) - COMPLETE
- [x] **Phase 2:** Sphere Backend (2-3 days) - COMPLETE
- [ ] **Phase 3:** API Schema (2-3 days)
- [ ] **Phase 4:** Core Env Wrapper (1 day)
- [ ] **Phase 5:** Agent Updates (3-4 days)
- [ ] **Phase 6:** Integration Testing (2 days)
- [ ] **Phase 7:** Documentation (1 day)

**Total Progress:** 2/7 phases (29%)

---

## Critical API Changes to Implement

### 1. Step API ⚠️ MOST IMPORTANT
```diff
- obs, reward, done, info = env.step(action)
+ obs, reward, terminated, truncated, info = env.step(action)
```

### 2. Reset API
```diff
- obs = env.reset()
+ obs, info = env.reset(seed=42)
```

### 3. Render Mode
```diff
- env.render(mode='human')
+ env = gym.make(..., render_mode='human')
+ env.render()
```

---

## Quick Task List

### Sphere (Python)
- [x] Update to `gymnasium>=1.0.0` (using 0.28.1 for Python 3.7 compatibility)
- [x] Change imports: `import gymnasium as gym`
- [x] Update `StepEnv()` return values
- [x] Update `ResetEnv()` return values
- [x] Build new Docker image (realorko/sphere-gymnasium:latest)

### API (Protobuf)
- [ ] Add `terminated` field to `StepEnvResponse`
- [ ] Add `truncated` field to `StepEnvResponse`
- [ ] Add `info` field to `ResetEnvResponse`
- [ ] Run `make generate`
- [ ] Update Gold vendor

### Gold Core (Go)
- [ ] Update `Outcome` struct
- [ ] Update `InitialState` struct
- [ ] Update `Step()` method
- [ ] Update `Reset()` method

### Agents (Go)
- [ ] **DeepQ:** Fix bootstrapping logic
- [ ] **PPO:** Fix mask calculation
- [ ] **REINFORCE:** Update training loop
- [ ] **NES:** Update training loop
- [ ] **HER:** Update hindsight logic
- [ ] **Q:** Update training loop

---

## Testing Checklist

- [ ] Sphere server starts successfully
- [ ] CartPole environment creates
- [ ] Step returns correct values
- [ ] Reset returns correct values
- [ ] DeepQ agent learns CartPole
- [ ] PPO agent learns CartPole
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Learning curves match baseline

---

## Session Log

| Session | Date | Duration | Tasks | Status |
|---------|------|----------|-------|--------|
| 1 | 2025-11-15 | 1h | Research & Planning | ✓ Complete |
| 2 | 2025-11-15 | 2h | Sphere Backend | ✓ Complete |
| 3 | - | - | API Update | Pending |
| 4 | - | - | Core Wrapper | Pending |
| 5-7 | - | - | Agents | Pending |
| 8 | - | - | Testing | Pending |
| 9 | - | - | Docs | Pending |

---

## Decision Tracker

| Decision | Status | Choice |
|----------|--------|--------|
| API Versioning | Pending | TBD (Phase 3) |
| Docker Image Name | ✓ Complete | realorko/sphere-gymnasium:latest |
| Sphere Repo Strategy | ✓ Complete | Forked to RealOrko/sphere, branch: gymnasium-migration |
| Gymnasium Version | ✓ Complete | 0.28.1 (Python 3.7 compatible) |
| Backward Compatibility | ✓ Complete | Combined terminated\|truncated into done |

---

## Blockers

*None currently*

---

## Next Session Goals

1. ~~Fork Sphere repository~~ ✓ Complete
2. ~~Update Python dependencies~~ ✓ Complete  
3. ~~Begin server.py modifications~~ ✓ Complete
4. Update API protobuf schema (Phase 3)
5. Regenerate Go/Python bindings
6. Update Gold core env wrapper

---

*Last Updated: 2025-11-15*
