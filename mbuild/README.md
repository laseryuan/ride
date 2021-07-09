For automate building muti-architecture docker images

```
cd mbuild
docker build -t mbuild .
docker run --rm -it -u $(id -u):$(id -g) -v $(pwd)/:/home/mbuild/ mbuild bash

```

Usage
```
cd ride

  mbuild \

docker run --rm -it \
  -v $(pwd)/:/home/mbuild/ \
  -v ~/.docker/:/root/.docker/ \
  -v /var/run/docker.sock:/var/run/docker.sock \
  lasery/mbuild \
bash


cd mbuild
python3 /home/utils/build.py docker
python3 /home/utils/build.py push --only
```

Test
```
python3 -m pytest \
  ./mbuild/utils/build.py \
  ./mbuild/utils/read_args.py \
  -s
```

Deploy
```
docker tag mbuild lasery/mbuild
docker push lasery/mbuild
```
