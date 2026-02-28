# WebArena Environment Setup Guide

## Problem

WebArena [CYR:требует] ~150GB for inwithех Docker [CYR:образо]in:
- Reddit (postmill): 53GB
- Shopping: 15GB  
- Shopping Admin: 15GB
- GitLab: 10GB
- Wikipedia: 90GB

Gitpod and[CYR:меет] [CYR:огран]and[CYR:чен]andе ~100GB on дandwithto.

## [CYR:Решен]andе: AWS AMI

WebArena [CYR:предо]withтаin[CYR:ляет] гfromоinый AMI with [CYR:преду]with[CYR:тано]in[CYR:ленным]and withерinandwithамand:

```
Region: us-east-2 (Ohio)
AMI ID: ami-08a862bf98e3bd7aa
Name: webarena-with-configurable-map-backend
Instance Type: t3a.xlarge (реto[CYR:омендует]withя)
Storage: 1000GB EBS
```

### [CYR:Шаг]and [CYR:запу]withtoа:

1. **[CYR:Создать] Security Group** with portамand:
   - 22 (SSH)
   - 7770 (Shopping)
   - 7780 (Shopping Admin)
   - 8023 (GitLab)
   - 8888 (Wikipedia)
   - 9999 (Reddit)
   - 3000 (Map)

2. **[CYR:Запу]withтandть EC2 andнwith[CYR:тан]with** andз AMI

3. **Наwith[CYR:тро]andть Elastic IP** for with[CYR:тат]andчеwithto[CYR:ого] [CYR:адре]withа

4. **[CYR:Запу]withтandть withерinandwithы**:
```bash
docker start gitlab shopping shopping_admin forum kiwix33
cd /home/ubuntu/openstreetmap-website/ && docker compose start
```

5. **Наwith[CYR:тро]andть URLs**:
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

6. **Эtowithportandроin[CYR:ать] [CYR:переменные]** in Gitpod:
```bash
export SHOPPING="${HOSTNAME}:7770"
export SHOPPING_ADMIN="${HOSTNAME}:7780/admin"
export REDDIT="${HOSTNAME}:9999"
export GITLAB="${HOSTNAME}:8023"
export WIKIPEDIA="${HOSTNAME}:8888/wikipedia_en_all_maxi_2022-05/A/User:The_other_Kiwix_guy/Landing"
export MAP="${HOSTNAME}:3000"
```

## [CYR:Запу]withto [CYR:бенчмар]toа

Поwithле onwith[CYR:трой]toand оto[CYR:ружен]andя:

```bash
cd /workspaces/vibee-lang
python3 scripts/run_webarena_benchmark.py
```

## [CYR:Сто]andмоwithть AWS

- t3a.xlarge: ~$0.15/чаwith
- 1000GB EBS: ~$100/меwithяц
- [CYR:Для] [CYR:полного] [CYR:прого]on 812 [CYR:задач] (~24 чаwithа): ~$4 + storage

## [CYR:Альтер]onтandinа: BrowserGym

ServiceNow BrowserGym [CYR:предо]withтаin[CYR:ляет] унandфandцandроin[CYR:анный] and[CYR:нтерфей]with:

```bash
pip install browsergym
```

[CYR:Поддерж]andin[CYR:ает] WebArena, VisualWebArena, WorkArena in едand[CYR:ном] API.
