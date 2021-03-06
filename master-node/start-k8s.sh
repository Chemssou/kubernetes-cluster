
## Checking commandline arguments
while test $# -gt 0; do
        case "$1" in
                -h|--help)
                        echo Usage:
                        echo "start-k8s.sh [proxy true]"
			exit 0
			;;
                -p|--proxy)
                        shift
                        if test $# -gt 0; then
                                export PROXY=$1
                        else
                                echo "invalid argument for proxy"
                                exit 1
                        fi
                        shift
                        ;;
		 *)
			break
			;;
        esac
done


#stop any running instance
/opt/docker-bootstrap/stop-k8s.sh

## Setting up env var
#############################################
export MASTER_IP=192.168.56.121  

# get from https://storage.googleapis.com/kubernetes-release/release/latest.txt  or /stable.txt
export K8S_VERSION=v1.4.0-alpha.1

# get from https://gcr.io/v2/google_containers/etcd-amd64/tags/list 
export ETCD_VERSION=2.2.5    

# get from https://quay.io/repository/coreos/flannel?tag=latest&tab=tags
export FLANNEL_VERSION=0.5.5   


# the interface that would connect all hosts 
export FLANNEL_IFACE=enp0s8 


export FLANNEL_IPMASQ=true


## starting docker boot-strap
/opt/docker-bootstrap/docker-boostrap start


echo "waiting for docker-bootstrap to start"
sleep 5

## starting up docker 
#sudo systemctl start docker


## start etcd
sudo docker -H unix:///var/run/docker-bootstrap.sock run -d \
    --net=host \
    gcr.io/google_containers/etcd-amd64:${ETCD_VERSION} \
    /usr/local/bin/etcd \
        --listen-client-urls=http://127.0.0.1:4001,http://${MASTER_IP}:4001 \
        --advertise-client-urls=http://${MASTER_IP}:4001 \
        --data-dir=/var/etcd/data
echo "waiting for etc-d to start"
sleep 25



## Save a network config 
sudo docker -H unix:///var/run/docker-bootstrap.sock run \
    --net=host \
    gcr.io/google_containers/etcd-amd64:${ETCD_VERSION} \
    etcdctl set /coreos.com/network/config '{ "Network": "10.1.0.0/16" }'

echo "waiting for network config to save"
sleep 5



## Run Flannel
flannel_image_id=$(sudo docker -H unix:///var/run/docker-bootstrap.sock run -d \
    --net=host \
    --privileged \
    -v /dev/net:/dev/net \
    quay.io/coreos/flannel:${FLANNEL_VERSION} \
    /opt/bin/flanneld \
        --ip-masq=${FLANNEL_IPMASQ} \
        --etcd-endpoints=http://${MASTER_IP}:4001 \
        --iface=${FLANNEL_IFACE})

echo "waiting for Flannel to pick up config"
sleep 5


echo Flannel config is
SET_VARIABLES=$(sudo docker -H unix:///var/run/docker-bootstrap.sock  exec $flannel_image_id  cat /run/flannel/subnet.env)
eval $SET_VARIABLES
sudo bash -c "echo [Service]  > /etc/systemd/system/docker.service.d/docker.conf"

if [ "$PROXY" == "true" ]
then
	sudo bash -c  "echo Environment=HTTP_PROXY=http://203.127.104.198:8080/ NO_PROXY=localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/16 FLANNEL_NETWORK=$FLANNEL_NETWORK FLANNEL_SUBNET=$FLANNEL_SUBNET FLANNEL_MTU=$FLANNEL_MTU >>/etc/systemd/system/docker.service.d/docker.conf"

else
	sudo bash -c  "echo Environment=FLANNEL_NETWORK=$FLANNEL_NETWORK FLANNEL_SUBNET=$FLANNEL_SUBNET FLANNEL_MTU=$FLANNEL_MTU >>/etc/systemd/system/docker.service.d/docker.conf" 

fi


echo FLANNEL_NETWORK=$FLANNEL_NETWORK FLANNEL_SUBNET=$FLANNEL_SUBNET FLANNEL_MTU=$FLANNEL_MTU 

## Delete docker networking 
sudo /sbin/ifconfig docker0 down
sudo brctl delbr docker0

## Start docker service 
sudo systemctl daemon-reload
sudo systemctl start docker
sudo systemctl status docker -l


## Start kubernetes master
sudo docker run \
    --volume=/:/rootfs:ro \
    --volume=/sys:/sys:ro \
    --volume=/var/lib/docker/:/var/lib/docker:rw \
    --volume=/var/lib/kubelet:/var/lib/kubelet:rw,rslave \
    --volume=/var/run:/var/run:rw \
    --net=host \
    --privileged=true \
    --pid=host \
    -d \
    gcr.io/google_containers/hyperkube-amd64:${K8S_VERSION} \
    /hyperkube kubelet \
        --allow-privileged=true \
        --api-servers=http://localhost:8080 \
        --v=2 \
        --address=0.0.0.0 \
        --enable-server \
        --hostname-override=127.0.0.1 \
        --config=/etc/kubernetes/manifests-multi \
        --containerized \
        --cluster-dns=10.0.0.10 \
        --cluster-domain=cluster.local

## Sleep 10
echo get all pods 
sleep 10
kubectl create -f dashboard-service.yaml --namespace=kube-system
kubectl get pod --all-namespaces
