set -x
rm -rf /root/test && mkdir /root/test && cd /root/test
tar -xJf /root/build/ComfyUI_linux_portable_cpu.tar.xz
mv ComfyUI_linux_portable /root/test/moved
cd /root/test/moved
ls -l /root/build/*.xz
./python_embeded/bin/python -s -c "import sys,torch;print(sys.version);print(torch.__version__)"
./update/update_comfyui.sh 2>&1 | tail -8
echo "UPDATE=${PIPESTATUS[0]}"
echo | ./update/update_comfyui_and_python_dependencies.sh 2>&1 | tail -6
echo "UPDATE_DEPS=${PIPESTATUS[1]}"
./python_embeded/bin/python -s ComfyUI/main.py --quick-test-for-ci --cpu > /root/test/quick.log 2>&1
echo "QUICKTEST=$?"
