# WebArena Environment Setup Guide

## Problem

WebArena [CYR:[TRANSLATED]] ~150GB for inwithех Docker [CYR:[TRANSLATED]]in:
- Reddit (postmill): 53GB
- Shopping: 15GB  
- Shopping Admin: 15GB
- GitLab: 10GB
- Wikipedia: 90GB

Gitpod and[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]andе ~100GB on дandwithto.

## [CYR:[TRANSLATED]]andе: AWS AMI

WebArena [CYR:[TRANSLATED]]withтаin[CYR:[TRANSLATED]] гfromоinый AMI with [CYR:[TRANSLATED]]with[TRANSLATED]]in[CYR:[TRANSLATED]]and withерinandwithамand:

```
Region: us-east-2 (Ohio)
AMI ID: ami-08a862bf98e3bd7aa
Name: webarena-with-configurable-map-backend
Instance Type: t3a.xlarge (реfor[TRANSLATED]]withя)
Storage: 1000GB EBS
```

### [CYR:[TRANSLATED]]and [CYR:[TRANSLATED]]withtoа:

1. **[CYR:[TRANSLATED]] Security Group** with portамand:
   - 22 (SSH)
   - 7770 (Shopping)
   - 7780 (Shopping Admin)
   - 8023 (GitLab)
   - 8888 (Wikipedia)
   - 9999 (Reddit)
   - 3000 (Map)

2. **[CYR:[TRANSLATED]]withтandть EC2 andнwith[TRANSLATED]]with** andз AMI

3. **Наwith[TRANSLATED]]andть Elastic IP** for with[TRANSLATED]]andчеwithfor[TRANSLATED]] [CYR:[TRANSLATED]]withа

4. **[CYR:[TRANSLATED]]withтandть withерinandwithы**:
```bash
docker start gitlab shopping shopping_admin forum kiwix33
cd /home/ubuntu/openstreetmap-website/ && docker compose start
```

5. **Наwith[TRANSLATED]]andть URLs**:
```bash
HOSTNAME="ec2-xx-xx-xx-xx.us-east-2.compute.amazonaws.com"

docker exec shopping /var/www/magento2/bin/magento setup:store-config:set --base-url="http://${HOSTNAME}:7770"
docker exec shopping mysql -u magentouser -pMyPassword magentodb -e "UPDATE core_config_data SET value='http://${HOSTNAME}:7770/' WHERE path = 'web/secure/base_url';"
docker exec shopping /var/www/magento2/bin/magento cache:flush

docker exec shopping_admin /var/www/magento2/bin/magento setup:store-config:set --base-url="http://${HOSTNAME}:7780"
docker exec shopping_admin mysql -u magentouser -pMyPassword magentodb -e "UPDATE core_config_data SET value='http://${HOSTNAME}:7780/' WHERE path = 'web/secure/base_url';"
docker exec shopping_admin /var/www/magento2/bin/magento cache:flush

docker exec gitlab sed -i "s|^external_url.*|external_url 'http://${HOSTNAME}:8023'|" /etc/gitlab/gitlab.rb
docker exec gitlab gitlab-ctl reconfigure
```

6. **Эtowithportandроin[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]** in Gitpod:
```bash
export SHOPPING="${HOSTNAME}:7770"
export SHOPPING_ADMIN="${HOSTNAME}:7780/admin"
export REDDIT="${HOSTNAME}:9999"
export GITLAB="${HOSTNAME}:8023"
export WIKIPEDIA="${HOSTNAME}:8888/wikipedia_en_all_maxi_2022-05/A/User:The_other_Kiwix_guy/Landing"
export MAP="${HOSTNAME}:3000"
```

## [CYR:[TRANSLATED]]withto [CYR:[TRANSLATED]]toа

Поwithле onwith[TRANSLATED]]toand оfor[TRANSLATED]]andя:

```bash
cd /workspaces/vibee-lang
python3 scripts/run_webarena_benchmark.py
```

## [CYR:[TRANSLATED]]andмоwithть AWS

- t3a.xlarge: ~$0.15/чаwith
- 1000GB EBS: ~$100/меwithяц
- [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]on 812 [CYR:[TRANSLATED]] (~24 чаwithа): ~$4 + storage

## [CYR:[TRANSLATED]]onтandinа: BrowserGym

ServiceNow BrowserGym [CYR:[TRANSLATED]]withтаin[CYR:[TRANSLATED]] унandфandцandроin[CYR:[TRANSLATED]] and[CYR:[TRANSLATED]]with:

```bash
pip install browsergym
```

[CYR:[TRANSLATED]]andin[CYR:[TRANSLATED]] WebArena, VisualWebArena, WorkArena in едand[CYR:[TRANSLATED]] API.
