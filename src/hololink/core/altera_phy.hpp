/**
 * SPDX-FileCopyrightText: Copyright (c) Altera Corporation
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once
#include <cstdint>

#include "hololink.hpp"

namespace hololink {

/***
 * Altera ETile Phy Driver
 */
class AlteraETile
{
public:
    AlteraETile(Hololink& hololink);
    void configure(const uint32_t base_addr, const uint32_t channel_offset, const uint32_t max_channels=8);

    uint8_t read_refclk(const uint32_t channel);

    bool task_refclk_sw(const uint32_t channel, const uint32_t refclk, const uint32_t hwseq);
    bool task_set_pma_attribute(const uint32_t channel, const uint32_t code, const uint32_t data);
    void task_pma_analog_reset(const uint32_t channel);

    
    uint8_t read_uint8(const uint32_t channel, const uint32_t reg);
    void write_uint8(const uint32_t channel, const uint32_t reg, const uint8_t value);

    uint32_t read_uint32(const uint32_t channel, const uint32_t reg);
    void write_uint32(const uint32_t channel, const uint32_t reg, const uint32_t value);

private:
    Hololink& hololink_;
    uint32_t etile_base_ = 0; // Base Address of the etile regsiters
    uint32_t etile_channel_offset_ = 0; // Offset for each channel
    uint32_t max_channels_ = 8; // Max number of channels
};

} // namespace hololink
