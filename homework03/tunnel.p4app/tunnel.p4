#include <core.p4>
#include <v1model.p4>

#include "header.p4"
#include "parser.p4"
    
control ingress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    action _drop() {
        mark_to_drop();
    }
    action set_nhop(bit<32> nhop_ipv4, bit<9> port) {
        meta.ingress_metadata.nhop_ipv4 = nhop_ipv4;
        standard_metadata.egress_spec = port;
        //standard_metadata.egress_spec = hdr.tunnel.tunnel_id;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }
    action set_dmac(bit<48> dmac) {
        hdr.ethernet.dstAddr = dmac;
    }
    action set_tunnel(bit<48> dmac, bit<9> port) {
        hdr.ethernet.dstAddr = dmac;
        standard_metadata.egress_spec = port;
    }
    table ipv4_lpm {
        actions = {
            _drop;
            set_nhop;
            NoAction;
        }
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        size = 1024;
        default_action = NoAction();
    }
    table forward {
        actions = {
            set_dmac;
            _drop;
            NoAction;
        }
        key = {
            meta.ingress_metadata.nhop_ipv4: exact;
        }
        size = 512;
        default_action = NoAction();
    }
    table tunnel_match {
        actions = {
            set_tunnel;
            _drop;
            NoAction;
        }
        key = {
            hdr.tunnel.tunnel_id: exact;
        }
        size = 512;
        default_action = NoAction();
    }
    apply {
        if (hdr.ipv4.isValid()) {
            ipv4_lpm.apply();
            forward.apply();
        }
        else if (hdr.tunnel.isValid()) {
	    tunnel_match.apply();
        }
    }
}

control egress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    action rewrite_mac(bit<48> smac) {
        hdr.ethernet.srcAddr = smac;
    }
    action _drop() {
        mark_to_drop();
    }
    table send_frame {
        actions = {
            rewrite_mac;
            _drop;
            NoAction;
        }
        key = {
            standard_metadata.egress_port: exact;
        }
        size = 256;
        default_action = NoAction();
    }
    apply {
        if (hdr.ipv4.isValid()) {
          send_frame.apply();
        }
    }
}

V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(), DeparserImpl()) main;
