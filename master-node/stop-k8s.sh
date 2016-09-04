sudo docker stop $(sudo docker ps -q)
sudo docker rm -f $(sudo docker ps -aq)
sudo docker rm -f $(sudo docker ps -aq)
sudo systemctl stop docker
sudo docker -H unix:///var/run/docker-bootstrap.sock stop $(sudo docker -H unix:///var/run/docker-bootstrap.sock ps -aq)
sudo docker -H unix:///var/run/docker-bootstrap.sock rm -f $(sudo docker -H unix:///var/run/docker-bootstrap.sock ps -aq)
sudo  ps -ef | grep /docker-bootstrap.sock  | grep -v grep | awk '{print $2}' | sudo xargs kill
sudo umount `cat /proc/mounts | grep /var/lib/kubelet | awk '{print $2}'`
sudo rm -rf /var/lib/kubelet
sudo umount /var/lib/docker-bootstrap/devicemapper

## Delete docker networking
sudo /sbin/ifconfig docker0 down
sudo brctl delbr docker0

