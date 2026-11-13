mkdir -p /root/build
WORK_DIR=/root/build bash /mnt/d/ComfyUI_dev/build_linux_portable.sh > /root/build.log 2>&1
echo "EXIT=$?" >> /root/build.log
