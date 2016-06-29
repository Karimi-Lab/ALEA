/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2007-2015 Broad Institute
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

package org.broad.igv.ga4gh;

import java.util.List;

/**
 * Created by jrobinso on 9/3/14.
 */
public class Ga4ghDataset {

    String id;
    String name;
    String genomeId;
    List<Ga4ghReadset> readsets;

    public Ga4ghDataset(String id, String name, String genomeId) {
        this.id = id;
        this.name = name;
        this.genomeId = genomeId;
    }

    public String getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public String getGenomeId() {
        return genomeId;
    }

    public List<Ga4ghReadset> getReadsets() {
        return readsets;
    }

    public void setReadsets(List<Ga4ghReadset> readsets) {
        this.readsets = readsets;
    }
}
