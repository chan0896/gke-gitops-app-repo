# 🚀 GKE GitOps CI/CD Pipeline

> **GitHub Actions + ArgoCD + Google Kubernetes Engine**  
> Terraform으로 구축한 GKE 클러스터 위에 GitOps 기반 CI/CD 파이프라인을 구성한 포트폴리오 프로젝트

---

## 📌 프로젝트 개요

| 항목 | 내용 |
|------|------|
| **목적** | 코드 변경 → 자동 빌드 → 자동 배포까지 이어지는 완전한 GitOps 파이프라인 구축 |
| **인프라** | GKE Standard Cluster (asia-northeast3) |
| **IaC** | Terraform (GCS 원격 백엔드) |
| **CI 도구** | GitHub Actions |
| **CD 도구** | ArgoCD |
| **레지스트리** | Google Artifact Registry |

---

## 🏗️ 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                        GitHub                               │
│                                                             │
│  [gke-gitops-app-repo]          [gke-gitops-manifests]     │
│  ├── app/index.html             ├── apps/nginx-app/        │
│  ├── Dockerfile                 │   ├── deployment.yaml    │
│  └── .github/workflows/ci.yaml  │   ├── service.yaml       │
│              │                  │   └── kustomization.yaml │
│              │ Push 감지        └──────────┬───────────────│
│              ↓                             │ 변경 감지      │
└──────────────┼─────────────────────────────┼───────────────┘
               │ CI                          │ CD
               ↓                             ↓
   ┌───────────────────┐        ┌─────────────────────────┐
   │  GitHub Actions   │        │        ArgoCD           │
   │                   │        │   (GKE 내부 설치)        │
   │  1. GCP 인증      │        │                         │
   │  2. Docker Build  │──────► │  gitops-repo 감시       │
   │  3. AR Push       │ 태그   │  변경 감지 → Auto Sync  │
   │  4. 태그 업데이트  │ 업데이트│                         │
   └───────────────────┘        └───────────┬─────────────┘
               │                            │ kubectl apply
               ↓                            ↓
   ┌───────────────────┐        ┌─────────────────────────┐
   │ Artifact Registry │        │      GKE Cluster        │
   │                   │        │  namespace: portfolio   │
   │ nginx-app:        │        │                         │
   │  sha-abc1234 ◄────┘        │  Deployment: nginx-app  │
   │  latest                    │  Service: LoadBalancer  │
   └───────────────────┘        └─────────────────────────┘
```

---

## 🔄 CI/CD 파이프라인 흐름

### CI — GitHub Actions

```
app/index.html 수정 후 main 브랜치 Push
        ↓
GitHub Actions 자동 트리거
        ↓
① GCP 서비스 계정 인증 (GCP_SA_KEY)
        ↓
② Docker 이미지 빌드
   nginx-app:sha-{commit_sha 앞 7자리}
        ↓
③ Artifact Registry Push
   asia-northeast3-docker.pkg.dev/gke-chan2026/gke-portfolio-repo/nginx-app
        ↓
④ gke-gitops-manifests 자동 커밋
   deployment.yaml image 태그 교체
   "chore: update nginx-app image to sha-xxxxxxx"
```

### CD — ArgoCD

```
gke-gitops-manifests 변경 감지
        ↓
현재 GKE 상태 vs gitops-repo 비교
        ↓
Out of Sync 감지
        ↓
Auto Sync → kubectl apply
        ↓
Rolling Update (무중단 배포)
        ↓
Healthy + Synced
```

---

## 🛠️ 기술 스택

| 분류 | 기술 |
|------|------|
| **Container** | Docker, Nginx Alpine |
| **Orchestration** | Google Kubernetes Engine (GKE) |
| **IaC** | Terraform >= 1.6, GCS Backend |
| **CI** | GitHub Actions |
| **CD** | ArgoCD (GitOps) |
| **Registry** | Google Artifact Registry |
| **Cloud** | Google Cloud Platform (asia-northeast3) |

---

## 📁 리포지토리 구조

```
gke-gitops-app-repo/          # 이 리포지토리 (CI 담당)
├── app/
│   └── index.html            # 웹 애플리케이션 소스
├── Dockerfile                # 컨테이너 이미지 빌드 정의
├── .gitignore
└── .github/
    └── workflows/
        └── ci.yaml           # GitHub Actions CI 파이프라인

gke-gitops-manifests/         # GitOps 리포지토리 (CD 담당)
└── apps/
    └── nginx-app/
        ├── namespace.yaml    # 네임스페이스 정의
        ├── deployment.yaml   # 배포 정의 (이미지 태그 자동 업데이트)
        ├── service.yaml      # LoadBalancer 서비스
        └── kustomization.yaml
```

---

## ⚙️ 인프라 구성 (Terraform)

```hcl
# GKE 클러스터 (모듈화)
module "gke" {
  source       = "../../modules/gke"
  cluster_name = "gke-portfolio-cluster-dev"
  region       = "asia-northeast3"
  machine_type = "e2-medium"
  min_nodes    = 1
  max_nodes    = 3
}

# VPC 네트워크 (모듈화)
module "vpc" {
  source        = "../../modules/vpc"
  network_name  = "gke-portfolio-vpc-dev"
  subnet_cidr   = "10.0.0.0/24"
  pods_cidr     = "10.1.0.0/16"
  services_cidr = "10.2.0.0/20"
}
```

**Terraform 백엔드**: GCS (`tf-state-gke-gke-chan2026`)

---

## 🔐 GitHub Secrets 구성

| Secret | 용도 |
|--------|------|
| `GCP_SA_KEY` | GCP 서비스 계정 키 (base64) |
| `GCP_PROJECT_ID` | GCP 프로젝트 ID |
| `GCP_REGION` | Artifact Registry 리전 |
| `GITOPS_REPO_TOKEN` | gitops-repo 자동 커밋용 PAT |

---

## 📋 GitOps 핵심 원칙 적용

| 원칙 | 적용 방식 |
|------|----------|
| **Single Source of Truth** | gke-gitops-manifests가 클러스터 상태의 유일한 기준 |
| **Declarative** | YAML 매니페스트로 원하는 상태 선언 |
| **Automated Sync** | ArgoCD Auto Sync로 선언 상태 자동 유지 |
| **Self-Healing** | kubectl 직접 수정 시 gitops-repo 상태로 자동 원복 |
| **Audit Trail** | 모든 배포가 git 커밋으로 추적 가능 |

---

## 🚀 배포 검증

```bash
# 클러스터 연결
gcloud container clusters get-credentials gke-portfolio-cluster-dev \
  --region=asia-northeast3

# 배포 상태 확인
kubectl get all -n portfolio-app

# ArgoCD 상태 확인
kubectl get application -n argocd

# 서비스 외부 IP 확인
kubectl get svc nginx-service -n portfolio-app
```

---

## 📊 트러블슈팅 경험

| 문제 | 원인 | 해결 |
|------|------|------|
| `sed: can't read deployment.yaml` | gitops-repo에 매니페스트 미생성 | gitops-repo 먼저 Push 후 CI 재실행 |
| `push declined due to secrets` | 키 파일이 커밋에 포함됨 | `.gitignore` 설정 + `git filter-repo` 로 히스토리 제거 |
| `kustomize build failed` | `kustomization.yaml` 내용 없음 | 파일 내용 작성 후 Push |
| ArgoCD namespace Terminating 지속 | finalizer 걸림 | `kubectl proxy` + finalize API 호출로 강제 삭제 |
| Terraform SA 권한 부족 | 최소 권한 설정으로 IAM 바인딩 실패 | `roles/resourcemanager.projectIamAdmin` 추가 |

---

*📅 구축 환경: GCP asia-northeast3 / GKE Standard Cluster / Terraform >= 1.6*  
*🔗 GitOps Manifests: [gke-gitops-manifests](https://github.com/chan0896/gke-gitops-manifests)*
