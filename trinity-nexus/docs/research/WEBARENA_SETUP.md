# WebArena Environment Setup Guide

## Problem

WebArena требует ~150GB for inwithех Docker образоin:
- Reddit (postmill): 53GB
- Shopping: 15GB  
- Shopping Admin: 15GB
- GitLab: 10GB
- Wikipedia: 90GB

Gitpod andмеет огранandченandе ~100GB on дandwithto.

## Решенandе: AWS AMI

WebArena предоwithтаinляет гfromоinый AMI with предуwithтаноinленнымand withерinandwithамand:

```
Region: us-east-2 (Ohio)
AMI ID: ami-08a862bf98e3bd7aa
Name: webarena-with-configurable-map-backend
Instance Type: t3a.xlarge (реtoомендуетwithя)
Storage: 1000GB EBS
```

### Шагand запуwithtoа:

1. **Создать Security Group** with портамand:
   - 22 (SSH)
   - 7770 (Shopping)
   - 7780 (Shopping Admin)
   - 8023 (GitLab)
   - 8888 (Wikipedia)
   - 9999 (Reddit)
   - 3000 (Map)

2. **Запуwithтandть EC2 andнwithтанwith** andз AMI

3. **Наwithтроandть Elastic IP** for withтатandчеwithtoого адреwithа

4. **Запуwithтandть withерinandwithы**:
```bash
docker start gitlab shopping shopping_admin forum kiwix33
cd /home/ubuntu/openstreetmap-website/ && docker compose start
```

5. **Наwithтроandть URLs**:
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

6. **Эtowithпортandроinать переменные** in Gitpod:
```bash
export SHOPPING="${HOSTNAME}:7770"
export SHOPPING_ADMIN="${HOSTNAME}:7780/admin"
export REDDIT="${HOSTNAME}:9999"
export GITLAB="${HOSTNAME}:8023"
export WIKIPEDIA="${HOSTNAME}:8888/wikipedia_en_all_maxi_2022-05/A/User:The_other_Kiwix_guy/Landing"
export MAP="${HOSTNAME}:3000"
```

## Запуwithto бенчмарtoа

Поwithле onwithтройtoand оtoруженandя:

```bash
cd /workspaces/vibee-lang
python3 scripts/run_webarena_benchmark.py
```

## Стоandмоwithть AWS

- t3a.xlarge: ~$0.15/чаwith
- 1000GB EBS: ~$100/меwithяц
- Для полного прогоon 812 задач (~24 чаwithа): ~$4 + storage

## Альтерonтandinа: BrowserGym

ServiceNow BrowserGym предоwithтаinляет унandфandцandроinанный andнтерфейwith:

```bash
pip install browsergym
```

Поддержandinает WebArena, VisualWebArena, WorkArena in едandном API.
