kubectl create -f namespace-spark-cluster.yaml
wait 5
kubectl get namespaces
#kubectl config set-context spark --namespace=spark-cluster --cluster=spark --user=Santanu
kubectl config use-context spark
kubectl create -f spark-master-controller.yaml
kubectl create -f spark-master-service.yaml
kubectl create -f spark-webui.yaml
#kubectl proxy --port=8001
kubectl create -f spark-worker-controller.yaml
#kubectl create -f spark-proxy-service.yaml
wait 5
kubectl get pods
kubectl create -f zeppelin-controller.yaml
kubectl create -f zeppelin-service.yaml 
sleep 5
kubectl get pods -l component=zeppelin

