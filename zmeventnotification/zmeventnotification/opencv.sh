#!/bin/bash
#
#
# Script to compile opencv with CUDA support.
#
# You need to prepare for compiling the opencv with CUDA support.
#
# You need to start with a clean docker image if you are going to recompile opencv.
# Unraid: This can be done by switching to "Advanced View" and clicking "Force Update".
# Other SYstems: Remove the docker image then reinstall it.
# Hook processing has to be enabled to run this script.
#
# Download the cuDNN package for your configuration from here:
# https://developer.nvidia.com/compute/machine-learning/cudnn/secure/v7.6.0.64/prod/10.1_20190516/Ubuntu18_04-x64/libcudnn7_7.6.0.64-1%2Bcuda10.1_amd64.deb
# Place it in /config folder.  You wll need to have an account with Nvidia to download this package.
#
CUDNN_PACKAGES=("libcudnn7_7.6.5.32-1+cuda10.1_amd64.deb" "libcudnn7-dev_7.6.5.32-1+cuda10.1_amd64.deb")

#
# github URL for opencv zip file download
# current default is to pull the version 4.2.0 release
OPENCV_URL=https://github.com/opencv/opencv/archive/4.2.0.zip
# uncomment the following URL to pull commit to support cudnn for older nvidia gpus
OPENCV_URL=https://github.com/opencv/opencv/archive/282fcb90dce76a55dc5f31246355fce2761a9eff.zip

#
#
# Insure hook processing has been installed.
#
if [ "$INSTALL_HOOK" != "1" ]; then
	echo "Hook processing has to be installed before you can compile opencv!"
	exit 1
fi

logger "Compiling opencv with GPU Support" -tEventServer

#
# Remove hook installed opencv module
#
pip3 uninstall opencv-contrib-python

#
# Install cuda toolkit
#
logger "Installing cuda toolkit..." -tEventServer
cd ~
wget https://developer.nvidia.com/compute/cuda/10.1/Prod/local_installers/cuda-repo-ubuntu1804-10-1-local-10.1.168-418.67_1.0-1_amd64.deb
dpkg -i cuda-repo-ubuntu1804-10-1-local-10.1.168-418.67_1.0-1_amd64.deb
apt-key add /var/cuda-repo-10-1-local-10.1.168-418.67/7fa2af80.pub
apt-get update
apt-get -y upgrade -o Dpkg::Options::="--force-confold"
apt-get -y install cuda
rm -r cuda-repo*

echo "export PATH=/usr/local/cuda/bin:$PATH" >/etc/profile.d/cuda.sh
echo "export LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/local/cuda/extras/CUPTI/lib64:/usr/local/lib:$LD_LIBRARY_PATH" >> /etc/profile.d/cuda.sh
echo "export CUDADIR=/usr/local/cuda" >> /etc/profile.d/cuda.sh
echo "export CUDA_HOME=/usr/local/cuda" >> /etc/profile.d/cuda.sh
echo "/usr/local/cuda/lib64" > /etc/ld.so.conf.d/cuda.conf
ldconfig
logger "Cuda toolkit installed" -tEventServer

#
# Install cuDNN package
#
logger "Installing cuDNN Package..." -tEventServer
for pkg in ${CUDNN_PACKAGES[@]}; do
    dpkg -i /config/$pkg
done
#
cudadir=/usr/local/cuda-10.1
if [ ! -d "$cudadir" ]; then
    logger "Failed to install cuda toolkit"
else
    ln -s $cudadir /usr/local/cuda
fi

logger "cuDNN Package installed" -tEventServer

#
# Compile opencv with cuda support
#
logger "Installing cuda support packages..." -tEventServer
apt-get -y install libjpeg-dev libpng-dev libtiff-dev libavcodec-dev libavformat-dev libswscale-dev
apt-get -y install libv4l-dev libxvidcore-dev libx264-dev libgtk-3-dev libatlas-base-dev gfortran
logger "Cuda support packages installed" -tEventServer

#
# Get opencv source
#
logger "Downloading opencv source..." -tEventServer
wget -O opencv.zip $OPENCV_URL
wget -O opencv_contrib.zip https://github.com/opencv/opencv_contrib/archive/4.2.0.zip
unzip opencv.zip
unzip opencv_contrib.zip
mv $(ls -d opencv-*) opencv
mv opencv_contrib-4.2.0 opencv_contrib

cd ~/opencv
mkdir build
cd build
logger "Opencv source downloaded" -tEventServer

#
# Make opencv
#
logger "Compiling opencv..." -tEventServer

cmake -D CMAKE_BUILD_TYPE=RELEASE \
	-D CMAKE_INSTALL_PREFIX=/usr/local \
	-D INSTALL_PYTHON_EXAMPLES=OFF \
	-D INSTALL_C_EXAMPLES=OFF \
	-D OPENCV_ENABLE_NONFREE=ON \
	-D WITH_CUDA=ON \
	-D WITH_CUDNN=ON \
	-D OPENCV_DNN_CUDA=ON \
	-D ENABLE_FAST_MATH=1 \
	-D CUDA_FAST_MATH=1 \
	-D WITH_CUBLAS=1 \
	-D OPENCV_EXTRA_MODULES_PATH=~/opencv_contrib/modules \
	-D HAVE_opencv_python3=ON \
	-D PYTHON_EXECUTABLE=/usr/bin/python3 \
	-D BUILD_EXAMPLES=OFF ..

exit
make -j$(nproc)
make install
ldconfig
logger "Opencv compiled" -tEventServer

#
# Clean up/remove unnecessary packages
#
logger "Cleaning up..." -tEventServer
cd ~
rm -r opencv*
apt-get -y remove cuda-toolkit-10-1
apt-get -y remove libjpeg-dev libpng-dev libtiff-dev libavcodec-dev libavformat-dev libswscale-dev
apt-get -y remove libv4l-dev libxvidcore-dev libx264-dev libgtk-3-dev libatlas-base-dev gfortran
apt-get -y autoremove

#
# Add opencv module wrapper
#
pip3 install opencv-contrib-python

logger "Opencv sucessfully compiled" -tEventServer
