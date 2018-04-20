#!/bin/bash

version="6.2.1"

rm -rf /home/elastic/.ssh/known_hosts

# Start all the clusters for the exam environment
# NOTE: Elasticsearch node folders can have any naming structure, 
# but Kibana instances must have "kibana" in the folder name

repo="elasticcertification/repo"
username="elastic"

for dir in */  
do
    #Remove the slash at the end of the folder name
    cluster_name=$(eval basename $dir)
    
    cd "$cluster_name"
    
    #Read in the cluster properties from the cluster.properties file
    props="./cluster.properties"
    if [[ ! -f "$props" ]]
    then
        echo "Skipping $cluster_name. No cluster.properties file found."
        cd ..
        continue
    fi
    
    while IFS='=' read -r key value
    do
   		eval ${key}=\${value}
    done < "$props"
    
    #Iterate through each subfolder and start up each node in a Docker container
    for dir in */ ; do
        #Remove the slash at the end of the folder name
        node_name=$(eval basename $dir)

        if [[ $node_name = *"kibana"* ]]; then
            #It's a Kibana node
            CID=$(docker run -d --restart always --privileged --dns 8.8.8.8 -p $kibana_host_port:$kibana_host_port  --name $node_name -h $node_name --publish-all=true -d  --net=es_bridge --ip 172.18.0.$kibana_ip --mount type=bind,source="$(pwd)"/$node_name/config,target=/home/$username/kibana/config -i -t $repo:$kibana_image-$version)
            server_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $node_name)	
            echo "$server_ip   $node_name"
        elif [[ $image = *"running"* ]]; then
            #It's a running ES node, so we use a unicast_hosts.txt file
            CID=$(docker run -d --restart always --privileged --dns 8.8.8.8  --name $node_name -h $node_name --publish-all=true -d  --net=es_bridge --ip 172.18.0.$ip --mount type=bind,source="$(pwd)"/$node_name/data,target=/home/$username/elasticsearch/data --mount type=bind,source="$(pwd)"/$node_name/config,target=/home/$username/elasticsearch/config --mount type=bind,source="$(pwd)"/$node_name/config/discovery-file,target=/home/$username/elasticsearch/config/discovery-file   -i -t $repo:$image-$version)
            server_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $node_name)	
            echo "$server_ip   $node_name"
           ((ip++))        
        else 
            #It's an ES node
            CID=$(docker run -d --restart always --privileged --dns 8.8.8.8  --name $node_name -h $node_name --publish-all=true -d  --net=es_bridge --ip 172.18.0.$ip --mount type=bind,source="$(pwd)"/$node_name/config,target=/home/$username/elasticsearch/config -i -t $repo:$image-$version)
            server_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $node_name)	
            echo "$server_ip   $node_name"
           ((ip++))        
        fi
    done
    cd ..
done

#For Github to work with empty folders, .gitignore was added to the path.data folders. Let's delete all of those
find . -name ".gitignore" -exec rm {} \;

echo "Clusters started. For convenience, add the output above to /etc/hosts on your local machine"