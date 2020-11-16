FROM alpine:3.12.1 as base

FROM base as builder

ENV LANG=C.UTF-8

RUN apk add --no-cache \
        ghostscript \
        alpine-sdk libffi-dev libxslt libxml2 autoconf automake libtool \
        zlib-dev \
        ca-certificates \
        curl \
        git \
        python3 \
        py3-virtualenv \
        py3-pip \
        qpdf \
        pngquant \
        tesseract-ocr \
        unpaper 

RUN apk add --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community \
        leptonica-dev \
        ocrmypdf

RUN apk add --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing \
        gosu

# Get the latest pip (Ubuntu version doesn't support manylinux2010)
RUN \
  curl https://bootstrap.pypa.io/get-pip.py | python3

# Compile and install jbig2
# Needs libleptonica-dev, zlib1g-dev
RUN \
  mkdir jbig2 \
  && curl -L https://github.com/agl/jbig2enc/archive/ea6a40a.tar.gz | \
  tar xz -C jbig2 --strip-components=1 \
  && cd jbig2 \
  && ./autogen.sh && ./configure && make && make install \
  && cd .. \
  && rm -rf jbig2


COPY src/requirements.txt /app/
RUN python3 -m venv --system-site-packages /appenv
RUN . /appenv/bin/activate && pip install -r /app/requirements.txt


### Begin Runtime Image
FROM base

ENV LANG=C.UTF-8

RUN apk add --no-cache \
  ghostscript \
  zlib-dev \
  pngquant \
  python3 \
  py3-virtualenv \
  qpdf \
  tesseract-ocr \
  tesseract-ocr-data-deu \
  unpaper

RUN apk add --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing \
        gosu

RUN apk add --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community \
        ocrmypdf \
        py3-img2pdf

WORKDIR /app

COPY --from=builder /usr/local/lib/ /usr/local/lib/
COPY --from=builder /usr/local/bin/ /usr/local/bin/
COPY --from=builder /appenv /appenv

RUN python3 -m venv --system-site-packages /appenv

RUN . /appenv/bin/activate;

COPY ./src /app


# Create restricted privilege user docker:docker to drop privileges
# to later. We retain root for the entrypoint in order to install
# additional tesseract OCR language packages.
RUN addgroup -g 1000 docker && \
    adduser --disabled-password --uid 1000 --home /app docker -G docker && \
    mkdir /config /input /output /ocrtemp /archive && \
    chown -Rh docker:docker /app /config /input /output /ocrtemp /archive && \
    chmod 755 /app/docker-entrypoint.sh

VOLUME ["/config", "/input", "/output", "/ocrtemp", "/archive"]

#CMD ["sh", "/app/docker-entrypoint.sh"]
ENTRYPOINT ["/app/docker-entrypoint.sh"]

