#!/bin/bash
##
## gce-disks-export: Export Google Cloud instances disks to Cloud Storage
## MIT License | Copyright (c) 2019 Fabio Ferrari
## GitHub repository: https://github.com/fabio-particles/gce-disks-export
##
## This software comes with ABSOLUTELY NO WARRANTY.
## This is free software, and you are welcome to redistribute it under certain conditions.
## More info about me visit: https//particles.io

GCE_DISKS=$(gcloud compute disks list | awk '{print $1}' | sed -n '2,$p')
BUCKET_NAME=$1
IMAGE_FORMAT=$2

usage() {
	echo "Usage: gcp-export-images BUCKET_NAME [IMAGE_FORMAT]"
	echo "Supported image formats: vmdk (default), vhdx, vpc, vdi, and qcow2"
	echo "Requires Google SDK: gcloud, gsutil and alpha commands"
	credits
}

credits() {
	echo "---"
	echo "MIT License | Copyright (c) 2019 Fabio Ferrari"
	echo "GitHub repository: https://github.com/fabio-particles/gce-disks-export"
	echo "---"
}

delete_image() {
	echo "---"
	echo "Remove image $diskname"
	gcloud compute images delete $1 -q &> /dev/null
}

if [ $# -eq 0 ]
	then
		usage
		echo "No arguments supplied"
		exit 1
fi

# Check if Bucket exists (BUCKET_NAME)
if ! gsutil ls gs://$BUCKET_NAME > /dev/null 2>&1
	then
		usage
		echo "Bucket $BUCKET_NAME not found!"
		echo "Create a new bucket or check permissions on GCP:"
		echo "https://console.cloud.google.com/storage/browser/"
		exit 1
fi

# Set default image format if not set as argument
if [ -z $IMAGE_FORMAT ]
	then
		IMAGE_FORMAT="vmdk"
		echo "No image format set, use vmdk as default format"
	else
		# Check if supplied image format is supported
		if  [ "$IMAGE_FORMAT" == "vmdk" ] || [ "$IMAGE_FORMAT" == "vhdx" ] [ "$IMAGE_FORMAT" == "vpc" ] || [ "$IMAGE_FORMAT" == "vdi" ] || [ "$IMAGE_FORMAT" == "qcow2" ]
			then
				echo "Use $IMAGE_FORMAT image format"
			else
				usage
				echo "Image format $IMAGE_FORMAT is not valid."
				exit 1
		fi
fi

##
## INTERACTIVE DISKS LIST
##

disk_num=0
echo "[0] All Disks"
for diskname in $GCE_DISKS
	do
		disk_num=$((disk_num+1))
		echo "[$disk_num] $diskname"
done

printf 'Select disk number to export, 0 for all disks: '
read -r selected_disk_num

if [ $selected_disk_num -eq 0 ]
	then
		echo "Selected All disks"
	else
		selected_disk_num=$((selected_disk_num+1))
		GCE_DISKS=$(gcloud compute disks list | awk '{print $1}' |  sed -n "${selected_disk_num}p")
		if [ -z "$GCE_DISKS" ]
			then
				echo "No disk found!"
				exit 1
		fi
		echo "Selected disk: $GCE_DISKS"
fi

##
## EXPORT PROCEDURE
##

for diskname in $GCE_DISKS
	do
		echo "---"
		echo "Exporting Image $diskimage"
		# Delete image if exists
		delete_image "$diskname"
		# Get disk zone
		diskzone="$(gcloud compute disks list | grep $diskname | awk '{print $2}')"
		echo "---"
		echo "Create new image for disk $diskname in zone $diskzone"
		gcloud compute images create $diskname \
			--source-disk $diskname \
			--source-disk-zone $diskzone \
			--force
		echo "---"
		echo "Export disk image $diskname.$IMAGE_FORMAT to Cloud Storage Bucket: $BUCKET_NAME"
		gcloud alpha compute images export \
				--destination-uri gs://$BUCKET_NAME/$diskname.$IMAGE_FORMAT \
				--image $diskname \
				--export-format $IMAGE_FORMAT
		# Delete image after exporting
		delete_image $diskname
done

credits
echo "Export is complete"