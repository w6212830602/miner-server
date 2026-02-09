package services

import (
	"errors"
	"fmt"
	"sort"
	"sync"
	"time"

	"miner-server/clients"
	"miner-server/models"
)

type ScanRequest struct {
	Base      string
	Start     int
	End       int
	TimeoutMs int
	Workers   int
}

type ScanResponse struct {
	Base      string        `json:"base"`
	Start     int           `json:"start"`
	End       int           `json:"end"`
	TimeoutMs int           `json:"timeout_ms"`
	Workers   int           `json:"workers"`
	ElapsedMs int64         `json:"elapsed_ms"`
	Miners    []models.Miner `json:"miners"`
}

type MinerService struct {
	client clients.MinerClient
}

func NewMinerService(client clients.MinerClient) *MinerService {
	return &MinerService{client: client}
}

func (s *MinerService) Validate(req ScanRequest) (ScanRequest, error) {
	if req.Base == "" {
		return req, errors.New("base is required")
	}

	// start/end basic validation
	if req.Start < 1 || req.Start > 254 || req.End < 1 || req.End > 254 || req.Start > req.End {
		return req, errors.New("invalid range: require 1<=start<=end<=254")
	}

	// timeout bounds
	if req.TimeoutMs <= 0 {
		req.TimeoutMs = 500
	}
	if req.TimeoutMs < 50 {
		req.TimeoutMs = 50
	}
	if req.TimeoutMs > 5000 {
		req.TimeoutMs = 5000
	}

	// worker bounds
	if req.Workers <= 0 {
		req.Workers = 30
	}
	if req.Workers > 200 {
		req.Workers = 200
	}

	return req, nil
}

func (s *MinerService) Scan(req ScanRequest) (ScanResponse, error) {
	req, err := s.Validate(req)
	if err != nil {
		return ScanResponse{}, err
	}

	startTime := time.Now()
	timeout := time.Duration(req.TimeoutMs) * time.Millisecond
	total := req.End - req.Start + 1

	type job struct{ ip string }
	jobs := make(chan job)
	results := make(chan models.Miner, total)

	var wg sync.WaitGroup
	for w := 0; w < req.Workers; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := range jobs {
				status := s.client.CheckStatus(j.ip, timeout)
				results <- models.Miner{IP: j.ip, Status: status}
			}
		}()
	}

	go func() {
		for i := req.Start; i <= req.End; i++ {
			ip := fmt.Sprintf("%s.%d", req.Base, i)
			jobs <- job{ip: ip}
		}
		close(jobs)
		wg.Wait()
		close(results)
	}()

	miners := make([]models.Miner, 0, total)
	for m := range results {
		miners = append(miners, m)
	}

	// stable order for UI
	sort.Slice(miners, func(i, j int) bool { return miners[i].IP < miners[j].IP })

	return ScanResponse{
		Base:      req.Base,
		Start:     req.Start,
		End:       req.End,
		TimeoutMs: req.TimeoutMs,
		Workers:   req.Workers,
		ElapsedMs: time.Since(startTime).Milliseconds(),
		Miners:    miners,
	}, nil
}
