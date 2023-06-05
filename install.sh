#!/bin/bash

# Function for custom installation logic
function custom_installation() {
    echo -e "Custom installation is not yet implemented. Please try again later."
}

# Function for default installation logic
function default_installation() {
    local version="$1"
    echo -e "\nStarting default installation for version ${version}..."
    
	# STEP 3 ---------------------
    # Install OS level packages
	sudo add-apt-repository universe -y
	sudo apt-get update -y
	sudo apt-get install -y git-core git-buildpackage debhelper devscripts python3.10-dev python3.10-venv virtualenvwrapper
	sudo apt-get install -y apt-transport-https ca-certificates curl lsb-release gnupg gnupg-agent software-properties-common vim
	
	# STEP 4 ---------------------
	# Add Docker repo and packages
	sudo mkdir -p /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	sudo chmod a+r /etc/apt/keyrings/docker.gpg
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt-get update -y
	sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose
	sudo apt autoremove --purge
	# Add your user to the Docker group
	sudo usermod -aG docker ${USER}
    
	# STEP 5 ---------------------
    # Follow the prompts to set the new user's information.
	# It is fine to accept the defaults to leave all of this information blank.
	sudo adduser geonode
	# The following command adds the user geonode to group sudo
	sudo usermod -aG sudo geonode
    
	# STEP 6 ---------------------
    # Make folder for the GeoNode project + user permissions
	sudo mkdir -p /opt/geonode_custom/
	sudo usermod -a -G www-data geonode
	sudo chown -Rf geonode:www-data /opt/geonode_custom/
	sudo chmod -Rf 775 /opt/geonode_custom/
	# Clone from the GeoNode repo
	cd /opt/geonode_custom/
	git clone https://github.com/GeoNode/geonode-project.git -b "$version"
	
	# STEP 7 ---------------------
	# Make the virtual environment
	source /usr/share/virtualenvwrapper/virtualenvwrapper.sh
	mkvirtualenv --python=/usr/bin/python3 my_geonode
	
	# STEP 8 ---------------------
	# Install Django and start the project from GeoNode template
	pip install Django==3.2.13
	django-admin startproject --template=./geonode-project -e py,sh,md,rst,json,yml,ini,env,sample,properties -n monitoring-cron -n Dockerfile my_geonode
	
	# STEP 9 ---------------------
	# Create .env file and build the container
	cd /opt/geonode_custom/my_geonode
	python3 create-envfile.py
  	docker-compose -f docker-compose.yml build --no-cache

	# STEP 10 --------------------
	# Run the container
  	docker-compose -f docker-compose.yml up -d
}

function ansible_installation() {
	local version="$1"
	echo -e "\nStarting Ansible installation for version ${version}..."
	
	# Check if Ansible is already installed
	if ! command -v ansible &> /dev/null; then
		echo "Ansible is not installed. Installing Ansible..."
		# Install Ansible
		sudo apt-get update
		sudo apt-get install -y ansible
	fi

	# If the .cfg and hosts file are in /root, it can cause problems
	# So we should remove it and create a new one in /etc instead

	# Check if .ansible.cfg file exists in root
	ansible_cfg="/root/.ansible.cfg"
	if [ -f "$ansible_cfg" ]; then
		echo "Removing $ansible_cfg"
		rm "$ansible_cfg"
	fi

	# Check if ansible_hosts file exists in root
	ansible_hosts="/root/ansible_hosts"
	if [ -f "$ansible_hosts" ]; then
		echo "Removing $ansible_hosts"
		rm "$ansible_hosts"
	fi

	# Check if the inventory file exists
	inventory_file="/etc/ansible/hosts"
	if [ ! -f "$inventory_file" ]; then
		# Create Ansible directories if they don't exist
		sudo mkdir -p /etc/ansible
		echo "Creating Ansible inventory file: $inventory_file"
		# Create the inventory file
		echo "[localhost]" | sudo tee "$inventory_file" > /dev/null
		echo "127.0.0.1 ansible_connection=local" | sudo tee -a "$inventory_file" > /dev/null
	fi

	# Check if the configuration file exists
	config_file="/etc/ansible/ansible.cfg"
	if [ ! -f "$config_file" ]; then
		echo "Creating Ansible configuration file: $config_file"
		# Create the configuration file
		echo -e "[defaults]\ninventory = /etc/ansible/hosts" | sudo tee "$config_file" > /dev/null
	fi

	# Set ANSIBLE_CONFIG environment variable
	export ANSIBLE_CONFIG="$config_file"

    # Install OS level packages
	sudo add-apt-repository universe -y
	sudo apt-get update -y
	sudo apt-get install -y git-core git-buildpackage debhelper devscripts python3.10-dev python3.10-venv virtualenvwrapper
	sudo apt-get install -y apt-transport-https ca-certificates curl lsb-release gnupg gnupg-agent software-properties-common vim
	
	# Add Docker repo and packages
	sudo mkdir -p /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	sudo chmod a+r /etc/apt/keyrings/docker.gpg
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt-get update -y
	sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose
	sudo apt autoremove --purge

	# Run the Ansible playbook passing the variables as command-line arguments
	sudo ansible-playbook -v geonode.yml --extra-vars "version=$version ansible_user=$USER"
}

# Clear console
clear

# Print header
echo -e "GeoNode Automated Docker Installer - Orchestrated beatifully at EEPIS"
echo -e "NOTE: Don't forget to run with sudo!\n"

# STEP 1 ---------------------
#  Check if argument is given for choice
if [ -n "$1" ]; then
 	choice=$1
else
	# Print menu
	echo "1. Default installation"
	echo "2. Custom installation"
	echo "3. Ansible installation"
	read -p "Enter your choice: " choice
	echo
fi

# Error checking for invalid choice
while [[ "$choice" != "1" && "$choice" != "2" && "$choice" != "3" ]]; do
    echo -e "\e[31mInvalid menu number, please try again.\e[0m"
    read -p "Enter your choice: " choice
    echo
done

# STEP 2 ---------------------
# Check if argument is given for version
if [ -n "$2" ]; then
	version=$2
else
	# Print version choices
	echo "Choose version:"
	echo "1. 3.1.x"
	echo "2. 3.2.x"
	echo "3. 3.3.x"
	echo "4. 4.0.x"
	echo "5. 4.1.x"
	read -p "Enter choice (1-5): " version
	
	# Set version based on user input
	case $version in
		"1") version="3.1.x";;
		"2") version="3.2.x";;
		"3") version="3.3.x";;
		"4") version="4.0.x";;
		"5") version="4.1.x";;
	esac
	echo
fi

# Error checking for invalid version number
while [[ "$version" != "3.1.x" && "$version" != "3.2.x" && "$version" != "3.3.x" && "$version" != "4.0.x" && "$version" != "4.1.x" ]]; do
    echo -e "\e[31mInvalid version number, please try again.\e[0m"
    read -p "Enter version number: " version
    echo
done

# Execute based on user input
if [ "$choice" = "1" ]; then
    default_installation $version
elif [ "$choice" = "2" ]; then
    custom_installation
elif [ "$choice" = "3" ]; then
    ansible_installation $version
fi

# Prompt for confirmation before exiting
read -n 1 -s -r -p "Press any key to continue..."
echo -e "\n"
