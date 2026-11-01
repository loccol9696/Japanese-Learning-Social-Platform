package com.jlsp.backend.subscription.repository;

import com.jlsp.backend.subscription.entity.SubscriptionPlan;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface SubscriptionPlanRepository extends JpaRepository<SubscriptionPlan, Long> {

    Optional<SubscriptionPlan> findByCode(String code);

    List<SubscriptionPlan> findByIsActiveTrueOrderByPriceAsc();
}
