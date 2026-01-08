与主机一样的网络,可以永久保存的docker
```
docker run -it   --name my-debian13 --network=host  -v /.data:/data   debian:trixie
```

连接
```
docker exec -it my-debian13 /bin/bash
```

apt cache
```
docker run -d \
  --name apt-cacher-ng \
  --restart always \
  -p 3142:3142 \
  -v /var/cache/apt-cacher-ng:/var/cache/apt-cacher-ng \
  sameersbn/apt-cacher-ng:latest
```

aptly share same ip with host

```
docker run \
  --detach=true \
  --network=host \
  --log-driver=syslog \
  --restart=always \
  --name="aptly" \
  --publish 80:80 \
  -v /.data:/data \
  urpylka/aptly:latest
```

aptly create repo
```
./keys_gen.sh "JimmyZhang" "wenewboy@gmail.com" ""
aptly repo create zuti-repo
aptly repo add zuti-repo /data/zfsutils-linux_2.3.5-2~bpo13+1_amd64.deb 
aptly repo add zuti-repo /data/zfs-dkms_2.3.5-2~bpo13+1_all.deb         
aptly publish -distribution trixie repo zuti-repo

```

debian linux
```
wget http://192.168.3.161/repo_signing.gpg -o /etc/apt/keyrings/
echo "deb [signed-by=/etc/apt/keyrings/repo_signing.gpg] http://192.168.3.161/ trixie main" > /etc/apt/source.list.d/local.list