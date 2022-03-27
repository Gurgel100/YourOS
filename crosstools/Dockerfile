# Build stage
FROM debian:11-slim as builder

RUN apt-get update && apt-get install -y build-essential libgmp10-dev libmpc-dev libmpfr-dev texinfo wget

RUN mkdir build
WORKDIR /build
COPY build_crosstools.sh .
COPY patches ./patches
COPY include /usr/local/youros/include
RUN mkdir /usr/local/youros/lib && chmod -R 777 /usr/local/youros

RUN ./build_crosstools.sh -d

# Final stage
FROM debian:11-slim as final

# Install runtime requirements
RUN apt-get update && apt-get upgrade -y && apt-get install -y fdisk git grub-pc-bin libgmp10 libmpc3 libmpfr6 make xorriso

# Copy required files from previous stage
COPY --from=builder /usr/local /usr/local

ENV SYSROOT_DIR=/usr/local/youros
WORKDIR /external