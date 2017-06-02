FROM mcranmer/dockers:dev

RUN wget https://bootstrap.pypa.io/get-pip.py && \
    python get-pip.py && \
    rm get-pip.py

RUN pip install google-api-python-client

WORKDIR /workspace

RUN ["/bin/zsh"]
