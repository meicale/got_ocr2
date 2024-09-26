ARG CUDA_VERSION=12.4.1
#################### BASE BUILD IMAGE ####################
# prepare basic build environment
# FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu24.04 AS base
FROM nvcr.io/nvidia/pytorch:23.10-py3 AS base
ARG CUDA_VERSION=12.4.1
ARG PYTHON_VERSION=3.12
ENV DEBIAN_FRONTEND=noninteractive

# Install Python and other dependencies
RUN echo 'tzdata tzdata/Areas select America' | debconf-set-selections \
  && echo 'tzdata tzdata/Zones/America select Los_Angeles' | debconf-set-selections \
  && apt-get update -y \
  && apt-get install -y ccache software-properties-common git curl sudo \
  && add-apt-repository ppa:deadsnakes/ppa \
  && apt-get update -y \
  && apt-get install -y python${PYTHON_VERSION} python${PYTHON_VERSION}-dev python${PYTHON_VERSION}-venv \
  && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 1 \
  && update-alternatives --set python3 /usr/bin/python${PYTHON_VERSION} \
  && ln -sf /usr/bin/python${PYTHON_VERSION}-config /usr/bin/python3-config \
  && curl -sS https://bootstrap.pypa.io/get-pip.py | python${PYTHON_VERSION} \
  && python3 --version && python3 -m pip --version

# # Workaround for https://github.com/openai/triton/issues/2507 and
# # https://github.com/pytorch/pytorch/issues/107960 -- hopefully
# # this won't be needed for future versions of this docker image
# # or future versions of triton.
# RUN ldconfig /usr/local/cuda-$(echo $CUDA_VERSION | cut -d. -f1,2)/compat/

RUN apt-get install -y python${PYTHON_VERSION}-distutils && apt-get install -y wget vim bzip2

RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-py312_24.7.1-0-Linux-x86_64.sh -O ~/miniconda.sh && \
  bash ~/miniconda.sh -b -p /opt/conda && \
  rm ~/miniconda.sh
ENV PATH /opt/conda/bin:$PATH
RUN conda update conda -y


WORKDIR /workspace
RUN git clone https://github.com/meicale/got_ocr2.git 
RUN conda create -n got python=3.10 -y \
  && conda run -n got pip install --no-cache-dir got_ocr2/GOT-OCR-2.0-master \
  && pip install ninja 

RUN  conda run -n got pip install flash-attn --no-build-isolation
# Install necessary system packages needed by OpenCV  
RUN apt-get update && apt-get install -y \
  libgl1-mesa-glx \
  libglib2.0-0 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*  

WORKDIR /workspace/got_ocr2/GOT-OCR-2.0-master 

# To work with the created environment, you might want to add:  
ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "got", "python", "GOT/demo/run_ocr_2.0.py" , "--model-name",  "/GOT_weights/",  "--type", "ocr", "--image-file" ]
CMD [ "-h" ]
