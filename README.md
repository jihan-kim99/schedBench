# today

## done

- 스케줄러 추가 가능
- 스케줄러 코스케줄링 가능
- 그라파나 프로메테우스 적용 완료
- 시뮬레이터를 활용한 학습

---

## TODO

>DDL 을 하고 싶어요

* Docker image 작성
    * 현재 오류로 인하여 실패
* pvc 랑 pv를 활용해서 테스트 작성
    
* 스케줄러 뜯어 보면서 공부해보기 뭐가 있고 어떻게 작동하는지 숙지하기

* 어떤 분야에 관하여 작성할지 정리하기

## Next
* 가능하다면 cloud function 만들어서 띄우고 거기다가 학습데이터 배치 받기 및 최종 모델 저장 하는 것 해봐야 할지도?  S3 랑 Lamda 사용

# month 6

# TODO

> 탈선하지 말것

## 노드 환경 다양화

__문제검__

- 단 하나의 컴퓨터에서 cpu를 가지고 작동함.
- 네트워크 밴드위스가 고로 존재 하지 않음.
- Data I/O 의 변화가 존재 하지 않음

__해결 방법__

- 노트북을 유선으로 연결 후 클러스터내의 노드로 추가함
- 현수형의 노트북과 컴퓨터를 온라인으로 연결하는 것이 가능한지 알아봄

## 스케줄러 추가

Network bandwidth aware 한 스케줄러를 사용하기 위한 리서치 및 적용
필요한 외부 API나 다른 것을 사용하는 경우 추가적인 코딩 필요

## PodGroup scheduling 개선

- Network Aware 한 코드 분석 및 추가
- Starvation 방지를 위한 Priority Scheduling 코드 분석 및 추가
- 가능하면 AI 사용한 스케줄러 가져와서 테스트 해보기

## Done
