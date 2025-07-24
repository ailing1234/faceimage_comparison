
brew install python

pip install opencv-python==4.7.0.72

/usr/local/bin/pip3 install flask
/usr/local/bin/python3 -c "from flask import Flask; print('Flask is working')"

brew --prefix python@3.10
ls $(brew --prefix python@3.10)/bin/python3.10
$(brew --prefix python@3.10)/bin/python3.10 -m venv venv
pip install --upgrade pip

rm -rf venv
python3.10 -m venv venv
source venv/bin/activate
pip install "numpy<2"
pip install numpy==1.24.4
pip install flask deepface
pip install -r requirements.txt
python deepface_api.py
