### Requirements
* docker
* docker-compose

#### Install Laravel
1. Create ```./src``` folder next to ```./docker```
2. ```make laravel-install```
3. There may be a problem with folder resolution. Run this: ```sudo chmod 777 -R ./src```
4. ```make laravel-init```

#### Install from existing repository
1. Create ```./src``` folder next to ```./docker```
2. Copy your project to the ```./src```
3. ```make laravel-init```

