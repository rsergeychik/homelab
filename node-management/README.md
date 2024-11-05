
Given playbook installs required packages to prepare raspberry pi nodes running Ubuntu to join microk8s cluster.

Merge configs like that ```KUBECONFIG=file1:file2:file3 kubectl config view \
    --merge --flatten > out.txt```

### Issues

1. ```Error1024: couldn't get current server API group list: the server has asked for the client to provide credentials```
    - Solution: ```kubectl config unset users.<user>.auth-provider```


