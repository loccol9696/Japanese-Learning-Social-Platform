package com.jlsp.backend.googlestt.service;

public interface VocalIsolationServiceIntf {

    byte[] separateVocals(byte[] audioFile) throws Exception;
}
