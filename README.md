# Exercise 8.2 — OIDC Federation + Secrets Manager

Reemplazo de la autenticación con **long-lived access keys** en el pipeline de CI por
autenticación **keyless** mediante el **OIDC provider** de GitHub, más almacenamiento de
un connection string en **AWS Secrets Manager**.

GitHub Actions prueba su identidad con un **short-lived token** y AWS concede acceso solo
si el token proviene de este repositorio y de la rama `main`.

## Arquitectura

```
GitHub Actions (push a main)
        │  solicita OIDC token (id-token: write)
        ▼
token.actions.githubusercontent.com
        │  AssumeRoleWithWebIdentity
        ▼
AWS IAM Role (oyd-exercise-8-2-ci-runner)
   trust policy: StringEquals sub == repo:SebastianAlecio/oyd-exercise-8-2:ref:refs/heads/main
                 StringEquals aud == sts.amazonaws.com
        │  credenciales temporales
        ▼
AWS (STS / Secrets Manager / ...)
```

## Estructura

```
oyd-exercise-8-2/
├── main.tf                  # OIDC provider, IAM role + trust policy, Secrets Manager
├── outputs.tf               # ARNs expuestos como outputs
├── .github/workflows/ci.yml # Workflow de CI con role-to-assume (keyless)
└── evidence/ci-run.png      # Screenshot del run exitoso de Actions
```

## Recursos Terraform

| Recurso | Descripción |
|---|---|
| `aws_iam_openid_connect_provider.github` | Registra el OIDC provider de GitHub en AWS. |
| `aws_iam_role.ci_runner` | Role que CI asume vía OIDC; trust policy con `StringEquals` sobre `sub` y `aud`. |
| `aws_iam_role_policy.ci_runner_read` | Permisos mínimos de solo lectura (`sts:GetCallerIdentity` + lecturas IAM/Secrets). |
| `aws_secretsmanager_secret.db_password` | Secret `oyd-exercise-8-2-db-password`. |
| `aws_secretsmanager_secret_version.db_password` | Valor placeholder; `lifecycle.ignore_changes = [secret_string]` para evitar drift en rotaciones. |

## Decisiones de seguridad

- **`StringEquals`, no `StringLike`**: el claim `sub` se compara de forma exacta. Un
  wildcard permitiría que *cualquier* repositorio asumiera el role.
- **`sub` exacto**: `repo:SebastianAlecio/oyd-exercise-8-2:ref:refs/heads/main` — solo la
  rama `main` de este repo.
- **`aud` = `sts.amazonaws.com`**: el token debe estar emitido para STS.
- **Sin secrets de AWS en GitHub**: `ci.yml` no contiene `aws-access-key-id` ni
  `aws-secret-access-key`; solo `role-to-assume`.

## Uso

```bash
terraform init
terraform apply -auto-approve
```

El output `ci_runner_role_arn` es el ARN que usa `role-to-assume` en `ci.yml`. Al hacer
push a `main` se dispara el workflow, que obtiene un OIDC token, asume el role y ejecuta
`terraform validate` sin credenciales almacenadas.

### Outputs

| Output | Descripción |
|---|---|
| `ci_runner_role_arn` | ARN del role que asume GitHub Actions. |
| `db_password_secret_arn` | ARN del secret en Secrets Manager. |
| `oidc_provider_arn` | ARN del OIDC provider. |

## Limpieza

```bash
terraform destroy -auto-approve
```

> **Nota:** la infraestructura de este ejercicio fue destruida con `terraform destroy`
> tras capturar la evidencia. El `state` de Terraform no se versiona (ver `.gitignore`).
