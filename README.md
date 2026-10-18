*This project has been created as part of the 42 curriculum by sohyamaz.*

# Inception

## Description

## Architecture

## Instructions

## Technical Choices

### Virtual Machines vs Docker
VMとDockerの大きな違いは、何をどこまで分離・仮想化するかにある。
VMはハードウェアを仮想化し、その上で独自のkernelを含むGuest OSを実行する。一方Docker Containerは独自のkernelを持たず、Host側のkernelを共有しながら、userland・filesystem・process・networkなどの実行環境を隔離する。
VMが文字通り「仮想化された別のPC」に近い環境を提供するのに対し、Dockerが提供するのは、Host kernel上で隔離されたアプリケーション実行環境である。
VMのメリットは、独自kernelを持つことによる強い隔離性と、Hostとは異なるOS環境まで構築できる点にある。一方Dockerはkernelを共有するため、VMより軽量で起動も速く、Imageによって同じ実行環境を容易に再現・配布できる。
したがってVMとDockerは単純な優劣関係ではなく、必要な隔離の強さ、互換性、実行効率、再現性などに応じて使い分けるものである。

### Secrets vs Environment Variables

### Docker Network vs Host Network

### Docker Volumes vs Bind Mounts

## Resources

## AI Usage
