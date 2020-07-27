## ec2 key replace

### Pre requsets
* Create a keypair to use. Download it and keep it where you build this container
* specify it when running
* working instance must accessible from where to job is running (this will easily be met if you run on AWS)

### Build
To import the key to be used you need your id_rsa\ pem file (downloaded or created for AWS)
The build process copies the file in to the container and uses when excutes

`docker build . -t ec2-key-switch`

### Run
To allow the utility to create and maipulate resources in AWS it requires some prevlidges
You can pass the `docker run` command IAM key and secret or rely on instance role.

example `docker run` command:
"""
docker run -d -e AWS_ACCESS_KEY_ID=AKI... -e AWS_SECRET_ACCESS_KEY=ps...Zen ec2-key-switch
"""