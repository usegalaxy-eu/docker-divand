# Jupyter container used for Galaxy IPython (+other kernels) Integration

# from 5th March 2021
FROM jupyter/datascience-notebook:julia-1.9.2

MAINTAINER Alexander Barth <a.barth@ulg.ac.be>

ENV DEBIAN_FRONTEND noninteractive
USER root

ADD run_galaxy.sh /usr/local/bin/run_galaxy.sh

RUN apt-get -qq update && \
    apt-get install -y \
    unzip \
    ca-certificates \
    curl && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# /import will be the universal mount-point for Jupyter
# The Galaxy instance can copy in data that needs to be present to the Jupyter webserver
RUN mkdir -p /import/jupyter/outputs/ && \
    mkdir -p /import/jupyter/data && \
    mkdir /export/ && \
    mkdir -p /home/$NB_USER/.julia/config /home/$NB_USER/.local && \
    mkdir -p /data/Diva-Workshops-data && \
    chown $NB_USER:users /data -R && \
    chown -R $NB_USER:users /home/$NB_USER/ /import /export/

USER jovyan

RUN JULIA_PACKAGES="CSV DataAssim DIVAnd DataStructures FFTW FileIO Glob HTTP IJulia ImageIO Images Interact Interpolations JSON Knet MAT Missings NCDatasets PackageCompiler PhysOcean PyCall PyPlot Roots SpecialFunctions StableRNGs VideoIO" \
    julia --eval 'using Pkg; Pkg.add(split(ENV["JULIA_PACKAGES"]))' && \
    julia --eval 'using Pkg; pkg"add PackageCompiler"'

RUN pip install --upgrade pip && \
    pip install --no-cache-dir \
        bioblend \
        galaxy-ie-helpers \
        jupyterlab_hdf
ADD ./get_notebook.py /get_notebook.py
ADD ./ipython-profile.py /home/$NB_USER/.ipython/profile_default/startup/00-load.py
    
# We can get away with just creating this single file and Jupyter will create the rest of the
# profile for us.
RUN mkdir -p /home/$NB_USER/.ipython/profile_default/startup/ && \
    mkdir -p /home/$NB_USER/.jupyter/custom/

ADD ipython-profile.py /home/$NB_USER/.ipython/profile_default/startup/00-load.py
ADD jupyter_notebook_config.py /home/$NB_USER/.jupyter/
ADD jupyter_lab_config.py /home/$NB_USER/.jupyter/
ADD ./custom.js /home/$NB_USER/.jupyter/custom/custom.js
ADD ./custom.css /home/$NB_USER/.jupyter/custom/custom.css
ADD ./default_notebook.ipynb /home/$NB_USER/notebook.ipynb

# Download notebooks
RUN mkdir -p /home/$NB_USER/
RUN cd   /home/$NB_USER/;  \
    wget -O master.zip https://github.com/gher-ulg/Diva-Workshops/archive/master.zip; unzip master.zip; \
    rm /home/$NB_USER/master.zip && \
    mv /home/$NB_USER/Diva-Workshops-master/notebooks /home/$NB_USER && \
    jupyter trust /home/$NB_USER/notebooks/*/*.ipynb && \
    rm -r /home/$NB_USER/Diva-Workshops-master

USER root

COPY startup.sh /startup.sh
COPY startup.jl /home/$NB_USER/.julia/config/startup.jl
COPY DIVAnd_precompile_script.jl /home/$NB_USER/
COPY make_sysimg.sh /home/$NB_USER/
RUN chown $NB_USER:users /home/$NB_USER/ -R && chmod 776 /home/$NB_USER/ -R 

USER jovyan

RUN julia -e 'using IJulia; IJulia.installkernel("Julia with 4 CPUs", env = Dict("JULIA_NUM_THREADS" => "4"))' && \
    ./make_sysimg.sh && \
    mv sysimg_DIVAnd.so DIVAnd_precompile_script.jl make_sysimg.sh DIVAnd_trace_compile.jl  /home/jovyan/.local && \
    rm -f test.xml Water_body_Salinity.3Danl.nc Water_body_Salinity.4Danl.cdi_import_errors_test.csv Water_body_Salinity.4Danl.nc Water_body_Salinity2.4Danl.nc && \
    julia -e 'using IJulia; IJulia.installkernel("Julia-DIVAnd precompiled", "--sysimage=/home/jovyan/.local/sysimg_DIVAnd.so")' && \
    julia -e 'using IJulia; IJulia.installkernel("Julia-DIVAnd precompiled, 4 CPUs)", "--sysimage=/home/jovyan/.local/sysimg_DIVAnd.so",env = Dict("JULIA_NUM_THREADS" => "4"))'

# ENV variables to replace conf file
ENV DEBUG=false \
    GALAXY_WEB_PORT=10000 \
    NOTEBOOK_PASSWORD=none \
    CORS_ORIGIN=none \
    DOCKER_PORT=none \
    API_KEY=none \
    HISTORY_ID=none \
    REMOTE_HOST=none \
    GALAXY_URL=none

RUN mkdir -p /home/$NB_USER/work/DIVAnd-Workshop/Adriatic/WOD && \
    curl https://dox.ulg.ac.be/index.php/s/Px6r7MPlpXAePB2/download | tar -C /home/$NB_USER/work/DIVAnd-Workshop -zxf - && \
    # This is from the old startup script, some work needs to be done here ... I would not put the data into /data and then symlink later. We can put them into 
    # /home/$NB_USER in the first place
    #mkdir -p /home/$NB_USER/work/DIVAnd-Workshop/Adriatic/WOD
    #ln -s /data/Diva-Workshops-data/WOD/* /home/$NB_USER/work/DIVAnd-Workshop/Adriatic/WOD/
    #chown $NB_USER /work/DIVAnd-Workshop/Adriatic/WOD

WORKDIR /import

# Start Jupyter Notebook
CMD /startup.sh

