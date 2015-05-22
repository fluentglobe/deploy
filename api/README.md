Steps for configuring the server for docker:
--------------------------------------------
### a) Add the swap to the droplet
https://www.digitalocean.com/community/tutorials/how-to-add-swap-on-ubuntu-14-04

### b) Install the packages
```
apt-get update
apt-get install docker nginx git
```

### c) Clone the deploy repo to /root
```
cd /root
git clone https://github.com/fluentglobe/deploy.git
```

### d) Configure and clone the fluentapi repo to /root
```
cp /root/deploy/api/config /root/deploy/api/id_rsa /root/.ssh
git clone git@github.com:fluentglobe/fluentapi.git
```

### e) Configure the docker deploy job
```
mkdir -p /scripts/deploy/
cp -pr /root/deploy/api/deploy_docker_container.sh  /scripts/deploy
chmod +x /scripts/deploy/deploy_docker_container.sh
```

### f) Add the following entry to crontab
```
*/5 * * * * bash /scripts/deploy/deploy_docker_container.sh
```

### g) Add logrotation configs
```
cp -pr /root/deploy/api/nginx /root/deploy/api/docker /etc/logrotate.d/
```

### h) Configure and restart nginx
```
cp -pr /root/deploy/api/default /etc/nginx/sites-available/
/etc/init.d/nginx restart
```
