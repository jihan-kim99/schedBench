# How to make scheduelr plugin

1. Go to `~/.zshrc` file and export the `GOPATH`

2. Make a directory to `$GOPATH/src/sigs.k8s.io`. eg: if GOPATH is `home/jihan`, 이 폴더 아래에 `src/sigs.k8s.io` 폴더를 만든다.

3. 방금 만든 `sigs.k8s.io` 폴더 안에서 Git 레파지토리를 clone한다.

```sh
git clone https://github.com/jihan-kim99/scheduler-plugins.git
```

4. `pkg` 폴더 아래에 만들고자 하는 스케줄러의 폴더를 만들고 코드를 작성한다.

|_pkg
    |_blockallschedule
        |_blockallschedule.go

스케줄러 파일에는 package이름을 명시하여야 하고, 이외에 이름을 반환하여야 한다.

```go
// blockallschedule.go

package blockallscheduler

const Name = "BlockAllScheduler"

func (pl *BlockAllScheduler) Name() string {
	return Name
}
```

5. 만든 스케줄러의 export이름을 `cmd/scheduler/main.go` 에 등록한다.

```go
//cmd/scheduler/main.go
import (
    ...
	blockallscheduler "sigs.k8s.io/scheduler-plugins/pkg/blockallschedule"
    ...
)

func main() {
	// Register custom plugins to the scheduler framework.
	// Later they can consist of scheduler profile(s) and hence
	// used by various kinds of workloads.
	command := app.NewSchedulerCommand(
		app.WithPlugin(blockallscheduler.Name, blockallscheduler.New),
        ...
    )
}

```

6. 이제 만들어진 코드를 이미지로 배포하기 위하여 `scheduler-plugin` 에서 `bash make.sh`를 돌리면 이미지를 만들고 hub에 push한다. hub에 올릴 이름은 각자 정의한다.

```sh

make local-image

VERSION="v$(date +%Y%m%d)-"
docker tag localhost:5000/scheduler-plugins/kube-scheduler:${VERSION} jinnkenny99/scheduler # 각자 정의
docker tag localhost:5000/scheduler-plugins/controller:${VERSION} jinnkenny99/controller # 각자 정의

# 각자 정의
docker push jinnkenny99/scheduler
docker push jinnkenny99/controller
```

7. 이후 `manifest/install/chart/as-a-second-scheduler`에서 helm 을 이용하여 배포한다. 이때 image를 바꿔 주어야 한다.

```yaml
#manifest/install/chart/as-a-second-scheduler/values.yaml

scheduler:
  name: scheduler-plugins-scheduler
  image: jinnkenny99/scheduler
  replicaCount: 1
  leaderElect: false
  nodeSelector: {}
  affinity: {}
  tolerations: []

controller:
  name: scheduler-plugins-controller
  image: jinnkenny99/controller
  replicaCount: 1
  nodeSelector: {}
  affinity: {}
  tolerations: []

```

이미지 변경이 끝났다면 같은 폴더내에서

```sh
helm install scheduler-plugins .
```

를 실행하면 된다.

8. 스케줄러의 이름을 바꾸지 않았음으로 기존과 동일하게 pod이나 deployment의 yaml에 스케줄러의 이름을 명시하면 된다.