#!/usr/bin/env bash
# KillerCoda CKA Scenario Launcher — SCENARIOS ONLY (no instructions/answers)
# Usage:
#   ./gen_lab.sh <QNUM>
#   ./gen_lab.sh clean
set -euo pipefail

APPLY() { kubectl apply --validate=false -f -; }
NS() { kubectl get ns "$1" >/dev/null 2>&1 || kubectl create ns "$1" >/dev/null; }
say() { echo "==> $*"; }

clean_all() {
  say "Cleaning practice namespaces and objects..."
  kubectl delete ns nginx-static autoscale echo-sound argocd priority mariadb backend frontend relative-fawn sp-culator q2-gateway synergy --ignore-not-found
  kubectl delete pv mariadb-pv --ignore-not-found
  rm -f /root/mariadb-deploy.yaml
  rm -rf ~/netpol
  say "Done."
}

# ---------------- Q1 ----------------
q1() {
  # Start with BOTH TLSv1.2 and TLSv1.3; you will later restrict to ONLY TLSv1.3
  NS nginx-static
  cat <<'EOF' | APPLY
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-static
  namespace: nginx-static
spec:
  replicas: 1
  selector: { matchLabels: { app: nginx-static } }
  template:
    metadata: { labels: { app: nginx-static } }
    spec:
      containers:
      - name: nginx
        image: nginx:stable
        ports: [{containerPort: 80}]
EOF
  cat <<'EOF' | APPLY
apiVersion: v1
kind: Service
metadata:
  name: nginx-static
  namespace: nginx-static
spec:
  selector: { app: nginx-static }
  ports:
  - port: 80
    targetPort: 80
EOF
  cat <<'EOF' | APPLY
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: nginx-static
data:
  ssl_protocols: "TLSv1.2 TLSv1.3"
EOF
  say "Q1 scenario ready."
}

# ---------------- Q2 ----------------
q2() {
  # Existing Ingress 'web' that you'll migrate to Gateway API
  NS q2-gateway
  cat <<'EOF' | APPLY
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-backend
  namespace: q2-gateway
spec:
  replicas: 1
  selector: { matchLabels: { app: web-backend } }
  template:
    metadata: { labels: { app: web-backend } }
    spec:
      containers:
      - name: nginx
        image: nginx:stable
        ports: [{containerPort: 80}]
EOF
  cat <<'EOF' | APPLY
apiVersion: v1
kind: Service
metadata:
  name: web-svc
  namespace: q2-gateway
spec:
  selector: { app: web-backend }
  ports:
  - port: 80
    targetPort: 80
EOF
  cat <<'EOF' | APPLY
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  namespace: q2-gateway
spec:
  tls:
  - hosts: ["gateway.web.k8s.local"]
    secretName: web-tls
  rules:
  - host: gateway.web.k8s.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-svc
            port:
              number: 80
EOF
  say "Q2 scenario ready."
}

# ---------------- Q3 ----------------
q3() {
  NS autoscale
  cat <<'EOF' | APPLY
apiVersion: apps/v1
kind: Deployment
metadata:
  name: apache-server
  namespace: autoscale
spec:
  replicas: 1
  selector: { matchLabels: { app: apache-server } }
  template:
    metadata: { labels: { app: apache-server } }
    spec:
      containers:
      - name: httpd
        image: httpd:2.4
        ports: [{containerPort: 80}]
        resources: {}
EOF
  cat <<'EOF' | APPLY
apiVersion: v1
kind: Service
metadata:
  name: apache-server
  namespace: autoscale
spec:
  selector: { app: apache-server }
  ports:
  - port: 80
    targetPort: 80
EOF
  say "Q3 scenario ready."
}

# ---------------- Q4 ----------------
q4() {
  NS echo-sound
  cat <<'EOF' | APPLY
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echoserver
  namespace: echo-sound
spec:
  replicas: 1
  selector: { matchLabels: { app: echoserver } }
  template:
    metadata: { labels: { app: echoserver } }
    spec:
      containers:
      - name: echoserver
        image: registry.k8s.io/echoserver:1.10
        ports: [{containerPort: 8080}]
EOF
  cat <<'EOF' | APPLY
apiVersion: v1
kind: Service
metadata:
  name: echoserver-service
  namespace: echo-sound
spec:
  selector: { app: echoserver }
  ports:
  - port: 8080
    targetPort: 8080
EOF
  say "Q4 scenario ready."
}

# ---------------- Q5 ----------------
q5() { say "Q5 scenario ready (no objects created)."; }

# ---------------- Q6 ----------------
q6() { say "Q6 scenario ready (no objects created)."; }

# ---------------- Q7 ----------------
q7() { NS argocd; say "Q7 scenario ready."; }

# ---------------- Q8 ----------------
q8() {
  # Seed a couple of user-defined PriorityClasses so you can compute (max-1)
  cat <<'EOF' | APPLY
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: user-p0
value: 10000
globalDefault: false
description: "Baseline user priority"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: user-p1
value: 100000
globalDefault: false
description: "Slightly higher user priority"
EOF
  NS priority
  cat <<'EOF' | APPLY
apiVersion: apps/v1
kind: Deployment
metadata:
  name: busybox-logger
  namespace: priority
spec:
  replicas: 2
  selector: { matchLabels: { app: busybox-logger } }
  template:
    metadata: { labels: { app: busybox-logger } }
    spec:
      containers:
      - name: bb
        image: busybox:stable
        command: ["sh","-c","sleep 3600"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: low-1
  namespace: priority
spec:
  replicas: 2
  selector: { matchLabels: { app: low-1 } }
  template:
    metadata: { labels: { app: low-1 } }
    spec:
      containers:
      - name: bb
        image: busybox:stable
        command: ["sh","-c","sleep 3600"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: low-2
  namespace: priority
spec:
  replicas: 2
  selector: { matchLabels: { app: low-2 } }
  template:
    metadata:
      labels: { app: low-2 }
    spec:
      containers:
      - name: bb
        image: busybox:stable
        command: ["sh","-c","sleep 3600"]
EOF
  say "Q8 scenario ready."
}

# ---------------- Q9 ----------------
q9() {
  NS sp-culator
  cat <<'EOF' | APPLY
apiVersion: apps/v1
kind: Deployment
metadata:
  name: front-end
  namespace: sp-culator
spec:
  replicas: 2
  selector: { matchLabels: { app: front-end } }
  template:
    metadata: { labels: { app: front-end } }
    spec:
      containers:
      - name: nginx
        image: nginx:stable
        # Intentionally no containerPort 80. You will add it.
EOF
  say "Q9 scenario ready."
}

# ---------------- Q10 ----------------
q10() { say "Q10 scenario ready (no objects created)."; }

# ---------------- Q11 ----------------
q11() {
  NS synergy
  cat <<'EOF' | APPLY
apiVersion: apps/v1
kind: Deployment
metadata:
  name: synergy-deployment
  namespace: synergy
spec:
  replicas: 1
  selector: { matchLabels: { app: synergy } }
  template:
    metadata: { labels: { app: synergy } }
    spec:
      containers:
      - name: app
        image: busybox:stable
        command: ["/bin/sh","-c"]
        args:
        - |
          mkdir -p /var/log
          while true; do date >> /var/log/synergy-deployment.log; sleep 2; done
EOF
  say "Q11 scenario ready."
}

# ---------------- Q12 ----------------
q12() { say "Q12 scenario ready (no objects created)."; }

# ---------------- Q13 ----------------
q13() {
  NS relative-fawn
  cat <<'EOF' | APPLY
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  namespace: relative-fawn
spec:
  replicas: 3
  selector: { matchLabels: { app: wordpress } }
  template:
    metadata: { labels: { app: wordpress } }
    spec:
      initContainers:
      - name: init-perms
        image: busybox
        command: ["sh","-c","echo init && sleep 1"]
      containers:
      - name: php-fpm
        image: bitnami/wordpress:latest
        ports: [{containerPort: 8080}]
      - name: web
        image: nginx:stable
        ports: [{containerPort: 80}]
EOF
  say "Q13 scenario ready."
}

# ---------------- Q14 ----------------
q14() {
  NS mariadb
  cat <<'EOF' | APPLY
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mariadb-pv
spec:
  capacity: { storage: 250Mi }
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /data/mariadb
EOF
  # Provide a deployment template file for your manual edits/application.
  cat > /root/mariadb-deploy.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mariadb
  namespace: mariadb
spec:
  replicas: 1
  selector:
    matchLabels: { app: mariadb }
  template:
    metadata:
      labels: { app: mariadb }
    spec:
      containers:
      - name: mariadb
        image: mariadb:10.6
        env:
        - name: MARIADB_ROOT_PASSWORD
          value: rootpass
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: mariadb
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mariadb
  namespace: mariadb
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests: { storage: 250Mi }
EOF
  say "Q14 scenario ready."
}

# ---------------- Q15 ----------------
q15() {
  # Place required cri-dockerd .deb at the expected path (best-effort fetch)
  say "Q15: fetching cri-dockerd .deb into ~/"
  DEB="cri-dockerd_0.3.9.3-0.ubuntu-jammy_amd64.deb"
  URL="https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.9/${DEB}"
  set +e
  curl -L -o ~/"$DEB" "$URL" 2>/dev/null || wget -q -O ~/"$DEB" "$URL"
  set -e
  if [ -f ~/"$DEB" ]; then
    say "Downloaded ~/${DEB}"
  else
    say "Could not download ${DEB}. You can fetch it manually from: ${URL}"
  fi
  say "Q15 scenario ready."
}

# ---------------- Q16 ----------------
q16() { say "Q16 scenario ready (no objects created)."; }

# ---------------- Q17 ----------------
q17() {
  NS frontend
  NS backend
  # Deployments + Services
  cat <<'EOF' | APPLY
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: frontend
spec:
  replicas: 1
  selector: { matchLabels: { app: frontend } }
  template:
    metadata: { labels: { app: frontend } }
    spec:
      containers:
      - name: nginx
        image: nginx:stable
        ports: [{containerPort: 80}]
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: frontend
spec:
  selector: { app: frontend }
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: backend
spec:
  replicas: 1
  selector: { matchLabels: { app: backend } }
  template:
    metadata: { labels: { app: backend } }
    spec:
      containers:
      - name: nginx
        image: nginx:stable
        ports: [{containerPort: 80}]
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: backend
spec:
  selector: { app: backend }
  ports:
  - port: 80
    targetPort: 80
EOF

  # Baseline deny-all in both namespaces
  cat <<'EOF' | APPLY
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: frontend
spec:
  podSelector: {}
  policyTypes: ["Ingress","Egress"]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: backend
spec:
  podSelector: {}
  policyTypes: ["Ingress","Egress"]
EOF

  # Label ns 'frontend' so namespaceSelector matches can work
  kubectl label ns frontend name=frontend --overwrite

  # Candidate policies for you to choose from (no hints)
  mkdir -p ~/netpol

  cat > ~/netpol/01-policy-a.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: policy-a
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes: ["Ingress"]
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: frontend
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 80
EOF

  cat > ~/netpol/02-policy-b.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: policy-b
  namespace: backend
spec:
  podSelector: {}
  policyTypes: ["Ingress"]
  ingress:
  - {}
EOF

  cat > ~/netpol/03-policy-c.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: policy-c
  namespace: frontend
spec:
  podSelector: {}
  policyTypes: ["Egress"]
  egress:
  - {}
EOF

  say "Q17 scenario ready."
}

# ---------------- Q18 ----------------
q18() { say "Q18 scenario ready (no objects created)."; }

main() {
  [[ "${1:-}" == "clean" ]] && { clean_all; exit 0; }
  Q="${1:-}"
  if [[ -z "$Q" ]]; then
    echo "Usage: $0 <QNUM|clean>"
    exit 1
  fi
  case "$Q" in
    1) q1 ;; 2) q2 ;; 3) q3 ;; 4) q4 ;; 5) q5 ;; 6) q6 ;;
    7) q7 ;; 8) q8 ;; 9) q9 ;; 10) q10 ;; 11) q11 ;; 12) q12 ;;
    13) q13 ;; 14) q14 ;; 15) q15 ;; 16) q16 ;; 17) q17 ;; 18) q18 ;;
    *) echo "Unknown question: $Q" ; exit 2 ;;
  esac
  say "Scenario Q$Q created."
}
main "$@"

