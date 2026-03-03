# Deployment Strategies Reference

## Strategy Comparison

| Strategy | Downtime | Risk | Rollback Speed | Resource Cost | Complexity |
|----------|----------|------|----------------|---------------|------------|
| **Recreate** | Yes | High | Slow | Low | Low |
| **Rolling** | No | Medium | Medium | Medium | Low |
| **Blue/Green** | No | Low | Fast | High (2x) | Medium |
| **Canary** | No | Very Low | Fast | Medium | High |
| **A/B Testing** | No | Low | Fast | Medium | High |

## Recreate Deployment

Stop old version completely, then start new version.

**Use when:**
- Development/test environments
- Application can't run multiple versions
- Downtime is acceptable

```yaml
# Kubernetes
spec:
  strategy:
    type: Recreate
```

```yaml
# GitHub Actions
- name: Stop old version
  run: kubectl scale deployment app --replicas=0

- name: Deploy new version
  run: |
    kubectl set image deployment/app app=$NEW_IMAGE
    kubectl scale deployment app --replicas=3
    kubectl rollout status deployment/app
```

## Rolling Deployment

Gradually replace old instances with new ones.

**Use when:**
- Standard deployments
- Need zero downtime
- Application supports multiple versions running

```yaml
# Kubernetes
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%        # Max extra pods during update
      maxUnavailable: 25%  # Max pods that can be unavailable
```

```yaml
# GitHub Actions
- name: Rolling deploy
  run: |
    kubectl set image deployment/app app=$NEW_IMAGE
    kubectl rollout status deployment/app --timeout=10m

- name: Rollback on failure
  if: failure()
  run: kubectl rollout undo deployment/app
```

### Rolling Deploy Patterns

```yaml
# Conservative (slower, safer)
rollingUpdate:
  maxSurge: 1
  maxUnavailable: 0

# Aggressive (faster, more resources)
rollingUpdate:
  maxSurge: 50%
  maxUnavailable: 50%

# Balanced (default)
rollingUpdate:
  maxSurge: 25%
  maxUnavailable: 25%
```

## Blue/Green Deployment

Maintain two identical environments, switch traffic between them.

**Use when:**
- Need instant rollback
- Full environment testing before switch
- Critical applications

```
        ┌─────────────────────────────────────────┐
        │            Load Balancer                │
        └─────────────────────────────────────────┘
                    │                  │
           ┌───────┴───────┐  ┌───────┴───────┐
           │   BLUE (v1)   │  │  GREEN (v2)   │
           │   [ACTIVE]    │  │   [STANDBY]   │
           └───────────────┘  └───────────────┘
```

### Kubernetes Implementation

```yaml
# blue-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: blue
  template:
    metadata:
      labels:
        app: myapp
        version: blue
    spec:
      containers:
        - name: app
          image: myapp:1.0.0
---
# green-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      containers:
        - name: app
          image: myapp:2.0.0
---
# service.yaml (switch by changing selector)
apiVersion: v1
kind: Service
metadata:
  name: app
spec:
  selector:
    app: myapp
    version: blue  # Change to 'green' to switch
  ports:
    - port: 80
```

### Pipeline Implementation

```yaml
# GitHub Actions
deploy-blue-green:
  steps:
    - name: Deploy to inactive environment
      run: |
        # Get current active color
        ACTIVE=$(kubectl get svc app -o jsonpath='{.spec.selector.version}')
        if [ "$ACTIVE" = "blue" ]; then
          TARGET="green"
        else
          TARGET="blue"
        fi
        echo "TARGET=$TARGET" >> $GITHUB_ENV

        # Deploy to inactive
        kubectl set image deployment/app-$TARGET app=$NEW_IMAGE
        kubectl rollout status deployment/app-$TARGET

    - name: Test inactive environment
      run: |
        # Get pod IP and test directly
        POD=$(kubectl get pod -l version=$TARGET -o name | head -1)
        kubectl exec $POD -- curl -f http://localhost/health

    - name: Switch traffic
      run: |
        kubectl patch svc app -p '{"spec":{"selector":{"version":"'$TARGET'"}}}'

    - name: Verify
      run: curl -f https://app.example.com/health

    - name: Rollback on failure
      if: failure()
      run: |
        OLD=$([ "$TARGET" = "green" ] && echo "blue" || echo "green")
        kubectl patch svc app -p '{"spec":{"selector":{"version":"'$OLD'"}}}'
```

## Canary Deployment

Route small percentage of traffic to new version, gradually increase.

**Use when:**
- High-risk changes
- Need real production testing
- Want to minimize blast radius

```
        ┌─────────────────────────────────────────┐
        │            Load Balancer                │
        │         90%              10%            │
        └─────────────────────────────────────────┘
           │                          │
    ┌──────┴──────┐           ┌───────┴───────┐
    │  Stable v1  │           │  Canary v2    │
    │  (3 pods)   │           │   (1 pod)     │
    └─────────────┘           └───────────────┘
```

### Kubernetes with Ingress

```yaml
# Nginx Ingress canary annotations
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-canary
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "10"  # 10% to canary
spec:
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app-canary
                port:
                  number: 80
```

### Progressive Canary Pipeline

```yaml
# GitHub Actions
canary-deploy:
  steps:
    - name: Deploy canary (10%)
      run: |
        kubectl apply -f k8s/canary-deployment.yaml
        kubectl patch ingress app-canary -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/canary-weight":"10"}}}'

    - name: Monitor (5 minutes)
      run: |
        for i in {1..30}; do
          ERROR_RATE=$(curl -s https://prometheus/api/v1/query?query=... | jq '.data.result[0].value[1]')
          if (( $(echo "$ERROR_RATE > 0.05" | bc -l) )); then
            echo "Error rate too high: $ERROR_RATE"
            exit 1
          fi
          sleep 10
        done

    - name: Increase to 50%
      run: |
        kubectl patch ingress app-canary -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/canary-weight":"50"}}}'

    - name: Monitor (5 minutes)
      run: ./scripts/monitor-canary.sh

    - name: Full rollout
      run: |
        kubectl set image deployment/app app=$NEW_IMAGE
        kubectl delete -f k8s/canary-deployment.yaml
        kubectl delete ingress app-canary

    - name: Rollback on failure
      if: failure()
      run: |
        kubectl delete -f k8s/canary-deployment.yaml
        kubectl delete ingress app-canary
```

### Canary with Argo Rollouts

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: app
spec:
  replicas: 5
  strategy:
    canary:
      steps:
        - setWeight: 10
        - pause: {duration: 5m}
        - setWeight: 30
        - pause: {duration: 5m}
        - setWeight: 60
        - pause: {duration: 5m}
      canaryMetadata:
        labels:
          role: canary
      stableMetadata:
        labels:
          role: stable
```

## Feature Flags

Deploy code with features disabled, enable gradually.

**Use when:**
- Decoupling deployment from release
- A/B testing
- Kill switch for features

```typescript
// Application code
if (featureFlags.isEnabled('new-checkout', userId)) {
  return newCheckoutFlow();
} else {
  return oldCheckoutFlow();
}
```

```yaml
# LaunchDarkly / Unleash integration
- name: Enable feature for 10%
  run: |
    curl -X PATCH https://app.launchdarkly.com/api/v2/flags/project/new-checkout \
      -H "Authorization: $LD_API_KEY" \
      -d '{"patch":[{"op":"replace","path":"/environments/production/rollout","value":{"variations":[{"variation":0,"weight":10000},{"variation":1,"weight":90000}]}}]}'
```

## Rollback Strategies

### Immediate Rollback (Kubernetes)

```bash
# Undo last deployment
kubectl rollout undo deployment/app

# Rollback to specific revision
kubectl rollout undo deployment/app --to-revision=2

# Check rollout history
kubectl rollout history deployment/app
```

### Automated Rollback

```yaml
- name: Deploy with auto-rollback
  run: |
    # Save current state
    kubectl get deployment app -o yaml > previous.yaml

    # Deploy
    kubectl set image deployment/app app=$NEW_IMAGE

    # Wait and verify
    if ! kubectl rollout status deployment/app --timeout=5m; then
      echo "Rollout failed, rolling back"
      kubectl apply -f previous.yaml
      exit 1
    fi

    # Health check
    if ! curl -f https://app.example.com/health; then
      echo "Health check failed, rolling back"
      kubectl rollout undo deployment/app
      exit 1
    fi
```

### Rollback Triggers

| Trigger | Threshold | Action |
|---------|-----------|--------|
| Error rate | > 5% | Auto rollback |
| Latency p99 | > 2s | Alert + manual |
| Health check | Fails 3x | Auto rollback |
| Crash loop | > 3 restarts | Hold rollout |
| Memory/CPU | > 90% | Alert + investigate |

## Environment Promotion

```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│   Dev   │--->│   QA    │--->│ Staging │--->│  Prod   │
└─────────┘    └─────────┘    └─────────┘    └─────────┘
     │              │              │              │
     v              v              v              v
  Auto on        Auto on        Auto on        Manual
  feature        develop        main           approval
  branch         merge          merge          required
```

```yaml
# Promotion pipeline
deploy-dev:
  environment: development
  rules:
    - if: $CI_COMMIT_BRANCH =~ /^feature\//

deploy-qa:
  environment: qa
  needs: [deploy-dev]
  rules:
    - if: $CI_COMMIT_BRANCH == "develop"

deploy-staging:
  environment: staging
  needs: [deploy-qa]
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

deploy-production:
  environment: production
  needs: [deploy-staging]
  when: manual
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
```
