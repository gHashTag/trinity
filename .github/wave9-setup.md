# Wave 9 Setup Instructions

## GitHub Secrets Required

Wave 9 deployment requires secrets for 8 Railway accounts. Add these secrets to GitHub:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `RAILWAY_PROJECT_ID` | aa0efa7f-95e6-4466-8de6-43945a031365 | FARM-1 project |
| `RAILWAY_ENVIRONMENT_ID` | 6748f1ad-9c2f-4b71-9a90-67f40ce34dc9 | FARM-1 environment |
| `RAILWAY_API_TOKEN` | c1b25b03-fbbc-49be-9b9d-934e0dd32933 | FARM-1 token |
| `RAILWAY_PROJECT_ID_2` | ca4303d2-4a09-4143-b725-9a3f3977118f | FARM-2 project |
| `RAILWAY_ENVIRONMENT_ID_2` | See .env | FARM-2 environment |
| `RAILWAY_API_TOKEN_2` | 7bfd5323-c0e9-4e04-aa1a-af04e82cab7d | FARM-2 token |
| `RAILWAY_PROJECT_ID_3` | 292e8862-11ce-4542-aff8-35a41e6b3217 | FARM-3 project |
| `RAILWAY_ENVIRONMENT_ID_3` | See .env | FARM-3 environment |
| `RAILWAY_API_TOKEN_3` | 18715192-2544-4626-a096-453f07de3cb4 | FARM-3 token |
| `RAILWAY_PROJECT_ID_8` | 5e2aa97e-d4ff-4f32-a329-4d1c4239049e | FARM-8 project |
| `RAILWAY_ENVIRONMENT_ID_8` | See .env | FARM-8 environment |
| `RAILWAY_API_TOKEN_8` | c4c42b13-2f35-4f14-acce-b078c2d4359a | FARM-8 token |
| `RAILWAY_PROJECT_ID_9` | 22bff7ef-6c44-4f90-9818-6050800c0dcf | FARM-9 project |
| `RAILWAY_ENVIRONMENT_ID_9` | See .env | FARM-9 environment |
| `RAILWAY_API_TOKEN_9` | f8766d58-c814-414e-acba-42fa5e651330 | FARM-9 token |
| `RAILWAY_PROJECT_ID_10` | 6e315376-05fa-4661-8a75-c605e9a7a1b3 | FARM-10 project |
| `RAILWAY_ENVIRONMENT_ID_10` | See .env | FARM-10 environment |
| `RAILWAY_API_TOKEN_10` | 39935ab4-2d4b-42f4-afc4-92c926b92324 | FARM-10 token |
| `RAILWAY_PROJECT_ID_11` | 088ccb3a-283e-4520-a4e4-2a741c0f659b | FARM-11 project |
| `RAILWAY_ENVIRONMENT_ID_11` | See .env | FARM-11 environment |
| `RAILWAY_API_TOKEN_11` | f33c9b2f-03ca-4c1a-a3b9-ae1df6a6503f | FARM-11 token |
| `RAILWAY_PROJECT_ID_12` | 6e7c1bc8-4e7d-4634-8d3e-e3c286d3a2e1 | FARM-12 project |
| `RAILWAY_ENVIRONMENT_ID_12` | See .env | FARM-12 environment |
| `RAILWAY_API_TOKEN_12` | b9d8239b-64a4-4ebd-89ab-d24e0c3c42a8 | FARM-12 token |

## Adding Secrets via gh CLI

```bash
# Example for FARM-2
gh secret set RAILWAY_PROJECT_ID_2 -b"ca4303d2-4a09-4143-b725-9a3f3977118f"
gh secret set RAILWAY_ENVIRONMENT_ID_2 -b"<value from .env>"
gh secret set RAILWAY_API_TOKEN_2 -b"7bfd5323-c0e9-4e04-aa1a-af04e82cab7d"
```

## Deploy After Secrets Set

1. Go to: https://github.com/gHashTag/trinity/actions/workflows/wave9-deploy.yml
2. Click "Run workflow"
3. Enter "YES" in confirm field
4. 8 parallel jobs will run

## Configuration

All 48 services will use:
- `HSLM_PROFILE` = s3-multiobj
- `HSLM_CTX` = 81
- `HSLM_NTP_WEIGHT` = 0.50
- `HSLM_JEPA_WEIGHT` = 0.25
- `HSLM_NCA_WEIGHT` = 0.25
- `HSLM_CRASH_TOLERANCE` = 0.05
- `HSLM_WAVE` = 9

## Service Naming

Format: `hslm-w9-{account}-{n}`

Examples:
- hslm-w9-1-01 (FARM-1, service 1)
- hslm-w9-2-06 (FARM-2, service 6)
- hslm-w9-12-03 (FARM-12, service 3)
