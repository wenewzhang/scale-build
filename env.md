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