package com.jlsp.backend.ai.service;

public interface VocalIsolationServiceIntf {

    byte[] separateVocals(byte[] audioFile) throws Exception;
}
