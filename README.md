# File Upload Server

A simple http server that accepts uploading files and serve them

# INSTALL

Requires perl and Carton-v1.0.901+:

    > git clone git://github.com/shoichikaji/File-Upload.git
    > cd File-Upload
    > carton install
    > carton exec perl script/file-upload-server
    # then http server is available at http://localhost:5000

## How to upload files

    > curl -T filename http://localhost:5000/upload/filename

## How to download files

    > curl -O http://localhost:5000/download/filename
    > wget http://localhost:5000/download/filename
