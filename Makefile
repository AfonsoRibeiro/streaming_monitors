container_name=streaming_monitors
image_name=streaming_monitors
image_version=0.0.9

main: build_go
	./${container_name} --log_level=debug --source_allow_insecure_connection=true --dest_allow_insecure_connection=true

curl:
	curl localhost:7700/metrics

run_trace: build_go
	./${container_name} --log_level=trace --source_allow_insecure_connection=true --dest_allow_insecure_connection=true

run_info: build_go
	./${container_name} --log_level=info --source_allow_insecure_connection=true --dest_allow_insecure_connection=true

build_go:
	go build -C src/main -o ../../${container_name}

pprof: build_go
	./${container_name} --pprof_on=true --log_level=debug

launch_pprof:
	/home/afonso_sr/go/bin/pprof -http=:8081 pprof/2023*.pprof

test_gojq:
	./tests/test_gojq.sh

run_container: build_cache
	docker run -d --rm --name ${container_name} --net host \
		-v `pwd`/monitors/:/app/monitors/:z \
		-v `pwd`/persistent_data/:/app/persistent_data/:z \
		--env SOURCE_PULSAR=pulsar://localhost:6650 \
		--env DEST_PULSAR=pulsar://localhost:6650 \
		--env LOG_LEVEL=debug \
		-p 7700:7700 \
		${image_name}:${image_version}
	docker logs -f ${container_name}

# workaround for dockerfile context
begin_build:
	mkdir -p build/gojq_extention/
	cp -r ../p2p_parser/go.* build/gojq_extention/
	cp -r ../gojq_extention/src build/gojq_extention/src

end_build:
	rm -r build/

build: begin_build
	echo "Building ${image_name}:${image_version} --no-cache"
	docker build -t ${image_name}:${image_version} . --no-cache
	make end_build

build_cache: begin_build
	echo "Building ${image_name}:${image_version} --with-cache"
	docker build -t ${image_name}:${image_version} .
	make end_build

docker_hub: build
	docker tag ${image_name}:${image_version} xcjsbsx/${image_name}:${image_version}
	docker push xcjsbsx/${image_name}:${image_version}

start_pulsar:
	docker run -d --rm --name pulsar -p 6650:6650 -p 8080:8080 apachepulsar/pulsar:latest bin/pulsar standalone

clean:
	rm ${container_name}; \
	rm -r persistent_data; \
	rm pprof/2023*; \
	rm monitors/configs/TEST_*; \
	rm -r monitors/TEST_*; \
	rm -r gojq_extention

.PHONY: clean start_pulsar docker_hub build_cache build run_container test_gojq launch_pprof pprof build_go run_trace curl main