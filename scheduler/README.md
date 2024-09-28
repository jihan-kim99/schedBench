# Scheduler

## How to run

이미 terraform, kind, kubectl이 있다는 전제하에.

`terraform apply --auto-approve`

를 실행하면 된다. 

kind cluster가 없는 경우 첫번째 실행에 에러가 발생한다. 이는 새로 생긴 cluster의 context가 아닌 과거의 context를 사용하여 발생한다.

한번 더 `terraform apply --auto-approve` 를 실행하면 정상적으로 작동한다.


## Scheduler Development

sched_docker 폴더 안에 있는 main.go를 기준으로 작성하였다. 같은 폴더 아래에 있는 docker.sh를 사용하여 작성이 끝난 코드를 docker hub로 배포할 수 있다. 또한 terraform apply 시 매번 코드가 수정되었다면 다시 docker로 배포하도록 하였다. 

만약 에러가 발생하여 버전 컨트롤이 필요한 경우 git lens나 stable한 버전을 정하여 사용하고자 한다. (예시: jinnkenny99/test-scheduler:0.18)
