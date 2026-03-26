package com.tongjing.server.repository;

import com.tongjing.server.entity.Spot;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface SpotRepository extends JpaRepository<Spot, Integer> {}
