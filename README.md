# Infraestrutura Kubernetes (EKS) e manifestos da aplicação AutoRepairShop.
---

## 📖 Sobre

Este repositório contém:
- **Infraestrutura como Código (Terraform):** Provisionamento do cluster EKS na AWS
- **Manifestos Kubernetes:** Deployments, Services, ConfigMaps, Secrets, HPA
- **CI/CD:** Validação e deploy automático via GitHub Actions
- **Observabilidade:** Datadog Agent no cluster (métricas, logs e APM)

---

## 🛠️ Tecnologias

- **Terraform** 1.6.6 - Infraestrutura como código
- **AWS EKS** 1.31 - Kubernetes gerenciado
- **Kubernetes** - Orquestração de containers
- **Docker** - Containerização
- **GitHub Actions** - CI/CD automático
- **kubectl** - CLI do Kubernetes
- **Horizontal Pod Autoscaler (HPA)** - Escalabilidade automática
- **Datadog** - Observabilidade (métricas, logs e APM no cluster)

---

## ✅ Pré-requisitos

- [Terraform](https://www.terraform.io/downloads) >= 1.6
- [kubectl](https://kubernetes.io/docs/tasks/tools/) >= 1.28
- [AWS CLI](https://aws.amazon.com/cli/) configurado
- Credenciais AWS com permissões: `eks:*`, `ec2:*`, `iam:*`, `elasticloadbalancing:*`
- Conta Datadog com **API Key** (secret `DD_API_KEY` no GitHub)

---

## 🚀 Instalação e Deploy

### **Método 1: Via CI/CD (Recomendado)**

1. **Configure os secrets no GitHub:**
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_SESSION_TOKEN`
   - `DD_API_KEY` (API Key da conta Datadog)

2. **Faça um commit / merge em `master`** (paths `k8s/**` ou workflow CD).

3. **O workflow CD irá:**
   - ✅ Aplicar Datadog Agent + Cluster Agent
   - ✅ Aplicar manifestos Kubernetes da API
   - ✅ Criar/atualizar LoadBalancer (NLB)
   - ✅ Configurar HPA
   - ✅ Reiniciar e aguardar rollout da API

### **Método 2: Deploy Manual**

```bash
git clone https://github.com/AutoRepairOrg/AutoRepairShop-Kubernetes.git
cd AutoRepairShop-Kubernetes

cd infra && terraform init && terraform apply
aws eks update-kubeconfig --name autorepairshop-eks --region us-east-1

cd ../k8s
kubectl apply -f namespace.yaml
kubectl apply -f api-configmap.yaml
kubectl apply -f api-secrets.yaml
kubectl apply -f api-deployment.yaml
kubectl apply -f api-service-nlb.yaml
kubectl apply -f api-hpa.yaml

export DD_API_KEY="sua-api-key-datadog"
export DD_TOKEN="$(openssl rand -hex 16)"
kubectl apply -f datadog-namespace.yaml
kubectl -n datadog create secret generic datadog-secret \
  --from-literal=api-key="$DD_API_KEY" \
  --from-literal=token="$DD_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f datadog-rbac.yaml
kubectl apply -f datadog-configmap.yaml
kubectl apply -f datadog-cluster-agent.yaml
kubectl apply -f datadog-agent-daemonset.yaml

kubectl get pods -n oficina
kubectl get pods -n datadog
```

---

## 📈 Monitoramento e Observabilidade (Datadog)

```
Pods (oficina) → stdout/métricas
                      ↓
         Datadog Agent (DaemonSet, 1 por node)
                      ↓
         Datadog Cluster Agent (métricas do cluster)
                      ↓
              Datadog SaaS (app.datadoghq.com)
```

| Componente | Função |
|------------|--------|
| `datadog-agent` (DaemonSet) | Logs, métricas de container/node, receiver APM |
| `datadog-cluster-agent` | Eventos e métricas do Kubernetes |
| Secret `datadog-secret` | API Key + token interno (criado no CD) |

Escopo: namespace **`oficina`**. Site padrão: `datadoghq.com` (US1).

### Validar

```bash
kubectl get pods -n datadog
kubectl logs -n datadog -l app=datadog-agent --tail=50
```

No Datadog:
1. **Infrastructure → Kubernetes** — nodes e pods
2. **Logs → Explorer** — filtro `kube_namespace:oficina`
3. **APM** — após instrumentar a API (próximo passo)

---

## 📁 Estrutura (trecho k8s)

```
k8s/
├── namespace.yaml / api-*.yaml / api-hpa.yaml
├── datadog-namespace.yaml
├── datadog-rbac.yaml
├── datadog-configmap.yaml
├── datadog-cluster-agent.yaml
└── datadog-agent-daemonset.yaml
```

---

## 📄 Licença

Tech Challenge - Fase 3 (FIAP).

**Autores:** Dhiulia da Silva, Mateus Pinheiro

## 🔗 Links

- [AutoRepairShop-Api](https://github.com/AutoRepairOrg/AutoRepairShop-Api)
- [AutoRepairShop-Database](https://github.com/AutoRepairOrg/AutoRepairShop-Database)
- [AutoRepairShop-Lambda](https://github.com/AutoRepairOrg/AutoRepairShop-Lambda)
